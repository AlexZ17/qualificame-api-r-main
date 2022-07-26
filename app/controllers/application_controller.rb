class ApplicationController < ActionController::API
	class BreakRequest < StandardError
		attr_reader :http_status, :errors

		def initialize(http_status: :bad_request, errors: nil)
			@http_status = http_status
			@errors = errors
			super()
		end
	end

	class InvalidParameter < ArgumentError
		attr_reader :param

		def initialize(param)
			@param = param
			super("param value is invalid: #{param}")
		end
	end

	# handle some expections with specific http_status responses
	rescue_from ActionController::ParameterMissing, InvalidParameter, BreakRequest,
		with: :break_request_handler

	private

		def param_to_datetime!(params_hash, param)
			datetime = params_hash[param]

			return unless datetime.present?
				
			begin
				datetime = Integer(datetime)
			rescue ArgumentError
				raise InvalidParameter(param)
			end
			
			Time.at(datetime)
		end

		def bad_request(errors = nil)
			raise BreakRequest.new(errors: errors)
		end

		def unauthorized(errors = nil)
			raise BreakRequest.new(http_status: :unauthorized, errors: errors)
		end

		def unprocessable_entity(errors = nil)
			raise BreakRequest.new(http_status: :unprocessable_entity, errors: errors)
		end

		def forbidden(errors = nil)
			raise BreakRequest.new(http_status: :forbidden, errors: errors)
		end

		def not_found(errors = nil)
			raise BreakRequest.new(http_status: :not_found, errors: errors)
		end

		def internal_server_error(errors = nil)
			raise BreakRequest.new(http_status: :internal_server_error, errors: errors)
		end

		def break_request_handler(ex)

			break_request = case ex
			when InvalidParameter, ActionController::ParameterMissing
				BreakRequest.new(http_status: :unprocessable_entity, errors: ex.message)
			else ex
			end

			errors = { error_description: break_request.errors } if 
				break_request.errors.is_a?(String)

			if errors
				render json: errors, status: break_request.http_status

			else head break_request.http_status
			end
		end
end
