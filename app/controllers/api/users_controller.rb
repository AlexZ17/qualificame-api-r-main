class Api::UsersController < ApiController
	before_action only: [:show] do
		doorkeeper_authorize! :admin, :kiosk
	end
	before_action only: [:update] do
		doorkeeper_authorize! :admin
	end

	# GET /api/me
	#
	def show
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)
		end
		
		render json: current_user
	end

	def update
		user_params = params.require(:user).
			permit(:current_password, :password, :password_confirmation)

		
		unless current_user.valid_password?( user_params.require(:current_password) )
			raise InvalidParameter.new(:current_password)
			# TODO: cool down change password with invalid current-password
		end if user_params[:password].present?

		user_params = user_params.except(:current_password)
		current_user.update(user_params)
		
		render json: current_user
	end

end
