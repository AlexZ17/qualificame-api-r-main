class Api::CompaniesController < ApiController
	before_action only: [:show] do
		doorkeeper_authorize! :admin, :kiosk
	end

	# GET /api/companies/:id
	#
	def show
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)
		end

		@company = Company.where(id: params[:id].to_i).take
		return not_found unless @company
		
		render json: @company
	end
end
