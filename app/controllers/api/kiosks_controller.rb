class Api::KiosksController < ApiController
	before_action only: [:index, :create, :update, :destroy] do
		doorkeeper_authorize! :admin
	end
	before_action only: [:show] do
		doorkeeper_authorize! :admin, :kiosk
	end

	# GET /api/kiosks
	#
	def index
		kiosk_ids = current_company.kiosks.pluck(:id)
		@kiosks = Kiosk.where(id: kiosk_ids).order(created_at: :desc).all

		# @kiosks.map(&:build_report) if @kiosks

		@kiosks.map{ |kiosk|
			start_datetime = kiosk.beginning_of_day ? 
				Time.zone.now.change({ 
					hour: kiosk.beginning_of_day.hour,
					min: kiosk.beginning_of_day.min,
					sec: kiosk.beginning_of_day.sec
				}) : Time.zone.now.beginning_of_day
			end_datetime = kiosk.end_of_day ? 
				Time.zone.now.change({ 
					hour: kiosk.end_of_day.hour,
					min: kiosk.end_of_day.min,
					sec: kiosk.end_of_day.sec,
					day: kiosk.beginning_of_day > kiosk.end_of_day ? Time.zone.now.day + 1 : Time.zone.now.day
				}) : Time.zone.now.end_of_day
			kiosk.build_report(start_datetime, end_datetime)
		} if @kiosks
		
		render json: @kiosks
	end
	
	# GET /api/kiosks/:id
	#
	def show
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)
		
		elsif scope == User::ADMIN
			return forbidden unless current_company.valid_kiosk?(params[:id].to_i)

		else
			return forbidden

		end

		@kiosk = Kiosk.where(id: params[:id].to_i).take
		return not_found unless @kiosk

		@kiosk.build_report
		
		render json: @kiosk
	end
	
	# POST /api/kiosks
	#
	def create
		@kiosk = build_params(Kiosk.new)
		return unless @kiosk
			
		@kiosk.build_report
		@kiosk.save
		
		render json: @kiosk
	end
	
	# PUT /api/kiosks/:id
	#
	def update
		return forbidden unless current_company.valid_kiosk?(params[:id].to_i)

		@kiosk = Kiosk.where(id: params[:id].to_i).take
		return not_found unless @kiosk
			
		return unless build_params(@kiosk)
			
		@kiosk.build_report
		@kiosk.save
		
		render json: @kiosk
	end

	# DELETE /api/kiosks/:id
	# 
	def destroy
		return forbidden unless current_company.valid_kiosk?(params[:id].to_i)

		@kiosk = Kiosk.where(id: params[:id].to_i).take

		@kiosk.destroy

		head :no_content
	end
	
	private
	
		def safe_params
			@safe_params ||= params.require(:kiosk).permit(
				:name,
				:welcome_message,
				:phone,
				:email,
				:address,
				:max_negative_percent,
				:min_positive_percent,
				:max_negative_events,
				:min_positive_events,
				:enabled_questions,
				:beginning_of_day,
				:end_of_day
			)
		end
		
		def build_params(kiosk)
			kiosk_params = safe_params

			if kiosk.new_record?
				kiosk.company = current_company
			
			elsif kiosk.company.nil?
				return not_found

			end
			
			kiosk.name = kiosk_params[:name] if 
				kiosk_params.has_key?(:name)
			
			kiosk.welcome_message = kiosk_params[:welcome_message] if 
				kiosk_params.has_key?(:welcome_message)
				
			kiosk.phone = kiosk_params[:phone] if 
				kiosk_params.has_key?(:phone)
				
			kiosk.email = kiosk_params[:email] if 
				kiosk_params.has_key?(:email)
				
			kiosk.address = kiosk_params[:address] if 
				kiosk_params.has_key?(:address)
				
			kiosk.max_negative_percent = kiosk_params[:max_negative_percent].to_f if 
				kiosk_params.has_key?(:max_negative_percent)
			
			kiosk.min_positive_percent = kiosk_params[:min_positive_percent].to_f if 
				kiosk_params.has_key?(:min_positive_percent)
				
			kiosk.max_negative_events = kiosk_params[:max_negative_events].to_i if 
				kiosk_params.has_key?(:max_negative_events)
				
			kiosk.min_positive_events = kiosk_params[:min_positive_events].to_i if 
				kiosk_params.has_key?(:min_positive_events)

			kiosk.enabled_questions = kiosk_params[:enabled_questions] if 
				kiosk_params.has_key?(:enabled_questions)

			kiosk.beginning_of_day = kiosk_params[:beginning_of_day] if
				kiosk_params.has_key?(:beginning_of_day)

			kiosk.end_of_day = kiosk_params[:end_of_day] if
				kiosk_params.has_key?(:end_of_day)
				
			kiosk.valid?
			
			kiosk
		end
end
