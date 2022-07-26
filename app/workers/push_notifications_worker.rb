class PushNotificationsWorker < ApplicationWorker

	EXPO_PUSH_URL = 'https://exp.host/--/api/v2/push'.freeze
	EXPO_SLICE_SIZE = 100

	class UnsupportedDevice < StandardError
	end

	attr_accessor :expo_messages, :expo_devices

	
	# send a basic push notification
	# 
	def send_message(title:, body:, user_id:, data: {})
		devices = MobileDevice.where(user_id: user_id, disabled: false).all.to_a
		return 0 if devices.empty?

		total_sent = 0
		self.expo_messages ||= []
		self.expo_devices ||= []

		data = data&.symbolize_keys! || {}

		devices.each{ |device|
			message = device.build_message(title: title, body: body, **data)

			if device.expo?
				expo_messages << message.merge(
					to: "ExponentPushToken[#{device.token}]")

				expo_devices << device

			else raise UnsupportedDevice
			end

			total_sent += 1
		}

		run_expo!
	end



	# check every Push Receipt from Expo
	#
	def expo_check_receipts(receipts:)
		receipts_index = Hash[receipts]

		request = Typhoeus::Request.new( "#{EXPO_PUSH_URL}/getReceipts", 
			method: :post,
			body: { ids: receipts_index.keys }.to_json, 
			headers: {
				'Content-Type' => 'application/json',
				'Accept'       => 'application/json'
			})
		
		request.run

		response = request.response
		body = JSON.parse(response.body) rescue {}

		# Rails.logger.debug(body.inspect)

		case response.code
		when 200
			devices_indexed = MobileDevice.where(id: receipts_index.values.uniq).all.index_by(&:id)

			body.fetch('data', {}).each{ |receipt, body_data|
				device_id = receipts_index[receipt]
				device = devices_indexed[device_id]
				next unless device

				case body_data['status']
				when 'ok'
				when 'error'
					expo_handle_ticket_errors(body_data: body_data, device: device)
				else logger.warn("Unprocessed response: #{body_data.inspect}")
				end
			}

		when 400..500 # client error
			expo_handle_request_errors(response, body: body)
		
		when 500..600 # server error
			expo_handle_request_errors(response, body: body)

			# TODO: retry later!
		else
			# TODO: retry later!
		end
	end


	private

		def run_expo!
			total_sent = 0

			# able to run multiple requests in parallel
			hydra = Typhoeus::Hydra.new
			requests = []

			expo_messages.each_slice(EXPO_SLICE_SIZE){ |messages|
				request = Typhoeus::Request.new( "#{EXPO_PUSH_URL}/send", 
					method: :post,
					body: messages.to_json, 
					headers: {
						'Content-Type' => 'application/json',
						'Accept'       => 'application/json'
					})
				requests << request
				hydra.queue(request)
			}

			hydra.run

			expo_receipts = []

			requests.each_with_index{ |request, request_idx|
				response = request.response
				body = JSON.parse(response.body) rescue {}

				# Rails.logger.debug(body.inspect)

				case response.code
				when 200
					total_sent += 1
					current_index = request_idx * EXPO_SLICE_SIZE
					
					body.fetch('data', []).each_with_index{ |body_data, ticket_idx|
						device = expo_devices[current_index + ticket_idx]
						next unless device

						case body_data['status']
						when 'ok'
							expo_receipts << [body_data['id'], device.id]
						when 'error'
							expo_handle_ticket_errors(body_data: body_data, device: device)
						end
					}

				when 400..500 # client error
					expo_handle_request_errors(response, body: body)
				
				when 500..600 # server error
					expo_handle_request_errors(response, body: body)

					# TODO: retry later!
				else
					# TODO: retry later!
				end
			}

			expo_receipts.each_slice(EXPO_SLICE_SIZE){ |expo_receipts|
				delay = rand(15) + 1
				
				PushNotificationsWorker.perform_in(delay, :expo_check_receipts, 
					{ receipts: expo_receipts })
			}

			total_sent
		end


		def expo_handle_request_errors(response, body:)
			errors = body.fetch('errors'){ [] }.map{ |error| 
				"#{error['code']}: #{error['message']}" }.join(', ')

			logger.error("  #{response.code} Errors: #{errors}")
		end


		def expo_handle_ticket_errors(body_data:, device:)
			error = body_data['details']&.[]('error')
			message = body_data['message'].to_s
			
			case error
			when 'DeviceNotRegistered'
				# stop sending messages
				device.disabled = true
				device.save
				return
				
			when 'MessageTooBig'
				# Halt! nothing to do.

			when 'MessageRateExceeded'
				# TODO: Retry!

			when 'InvalidCredentials'
				# TODO: Notify Admin!
			
			else  # unknown error
				if message =~ /is associated with a different experience/
					device.disabled = true
					device.save
					return
				end
			end

			logger.error(body_data)
		end

end