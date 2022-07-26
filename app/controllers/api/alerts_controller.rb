class Api::AlertsController < ApiController
	include Qualificame::Params
	before_action only: [:index, :update] do
		doorkeeper_authorize! :admin
	end

	# GET /api/alerts
	#
	def index
		kiosk_ids = current_company.kiosks.pluck(:id)
		@alerts = Alert.where(kiosk_id: kiosk_ids).order(created_at: :desc).all

		meta = {}
		
		params_pagination(max_limit: 30){ |limit, offset|
			meta[:total] = total = @alerts.count
			
			@alerts = offset >= total ? 
				@alerts.none :
				@alerts.limit(limit).offset(offset).order(:id)
		}
		
		@alerts = @alerts.all

		meta = nil unless meta.present?
		
		render json: @alerts, each_serializer: AlertSerializer, meta: meta
	end

	# PUT /api/alerts/:id
	#
	def update
		@alert = Alert.where(id: params[:id].to_i).take

		return forbidden unless current_company.valid_kiosk?(@alert&.kiosk_id)
		return not_found unless @alert
			
		return unless build_params(@alert)
		
		@alert.save
		
		render json: @alert
	end

	private
	
		def safe_params
			@safe_params ||= params.require(:alert).permit(
				:kiosk_id,
				:read
			)
		end
		
		def build_params(alert)
			alert_params = safe_params

			alert.read = alert_params[:read] if 
				alert_params.has_key?(:read)
				
			alert.valid?
			
			alert
		end
end
