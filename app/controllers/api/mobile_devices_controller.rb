class Api::MobileDevicesController < ApiController
	before_action only: [:create] do
		doorkeeper_authorize! :admin
	end	
	# POST /api/mobile_devices
	# 
	# Register a mobile device for push messaging.
	# this action is idempotent, so if we find the 
	# token we just update and enable the endpoint.
	#
	def create
		
		if safe_params.has_key?(:ios_token)
			token = safe_params.require(:ios_token)
			type = MobileDevice::TYPE_IOS
		
		elsif safe_params.has_key?(:gcm_token)
			token = safe_params.require(:gcm_token)
			type = MobileDevice::TYPE_GCM

		elsif safe_params.has_key?(:expo_token)
			token = safe_params.require(:expo_token)
			type = MobileDevice::TYPE_EXPO
		
		else return bad_request
		end

		return bad_request('Invalid format') unless token =~ /ExponentPushToken\[(.{22})\]/
		token = $1

		# probably a returning user on the same device?
		new_device   = MobileDevice.where(token: token, platform_type: type).take
		new_device ||= MobileDevice.new(token: token, platform_type: type)

		new_device.user = current_user
		new_device.disabled = false
		new_device.save

		head :no_content
	end

	private
		def safe_params
			@safe_params ||= params.require(:mobile_device).permit(
				:ios_token,
				:gcm_token,
				:expo_token,
			)
		end
end