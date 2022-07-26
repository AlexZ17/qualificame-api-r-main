class Api::KioskDevicesController < ApiController
	before_action only: [:index, :update] do
		doorkeeper_authorize! :admin
	end

	# GET /api/kiosks/:kiosk_id/kiosk_devices
	# 
	def index
		return forbidden unless kiosk_id = params[:kiosk_id].to_i and kiosk_id > 0

		@kiosk_devices = KioskDevice.where(kiosk_id: kiosk_id, status: KioskDevice::CLAIMED).all
		#@kiosk_devices = nil
		render json: @kiosk_devices
	end

	# PUT /api/logout_device
	#
	def logout_kiosk_device
		kiosk_devices_ids = params[:kiosk_devices_ids]
		kiosk_devices = KioskDevice.where(id: kiosk_devices_ids).all

		kiosk_devices.map(&:forgotten!)
	end

	# PUT /api/register_kiosk
	#
	def update
		kiosk_params = params.require(:kiosk_device).permit(:token, :kiosk_id, :name)

		kiosk_id = kiosk_params[:kiosk_id].to_i
		return forbidden unless current_company.valid_kiosk?(kiosk_id)

		token    = KioskDevice.is_valid?(token: kiosk_params[:token])
		raise ApplicationController::InvalidParameter.new(:token) unless 
			token and kiosk_id

		if token.has_key?(:uuid)
			old_devices = KioskDevice.where("(uuid = ? or kiosk_id = ?) and status = ?", token[:uuid], kiosk_id, KioskDevice::CLAIMED).all
			# old_devices.map(&:forgotten!) if old_devices

			@kiosk_device = KioskDevice.new(name: kiosk_params[:name],uuid: token[:uuid], status: KioskDevice::CLAIMED, kiosk_id: kiosk_id)
			@kiosk_device.save

			Sidekiq.redis{ |redis| 
				redis.del("kiosk:#{token[:uuid]}")
			}
			
			render json: @kiosk_device
		end

		head :no_content
	end
	
end
