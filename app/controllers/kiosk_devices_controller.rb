class KioskDevicesController < ApplicationController

	def show
		uuid = params[:uuid]

		if uuid
			@kiosk_device = KioskDevice.claimed.by_uuid(uuid).take

			if @kiosk_device
				user = User.where(company_id: @kiosk_device.kiosk.company_id).take

				oauth_token = Doorkeeper::AccessToken.find_or_create_for(
					# application, resource_owner_id, scopes, expires_in, use_refresh_token
					#nil, user.id, 'kiosk', 2.hours, true
					application: nil, resource_owner: user.id, scopes: 'kiosk', expires_in: 2.hours, use_refresh_token: true
					#application: nil, resource_owner: user.id, scopes: 'kiosk', expires_in: 3.seconds, use_refresh_token: true
				)

				response_json = {
					uuid: uuid,
					kiosk_id: @kiosk_device.kiosk.id,
					access_token: oauth_token.token,
					token_type: 'bearer',
					expires_in: oauth_token.expires_in,
					refresh_token: oauth_token.refresh_token,
					scope: oauth_token.scopes,
					created_at: oauth_token.created_at.to_i
				}

			else
				response_json = KioskDevice.redis_token(uuid: uuid)

				raise ApplicationController::InvalidParameter.new(:uuid) unless response_json
			end

		else
			response_json = KioskDevice.redis_token
		end

		render json: response_json
	end

end
