class Api::EventsController < ApiController
	include Qualificame::Params
	before_action only: [:index, :show] do
		doorkeeper_authorize! :admin
	end
	before_action only: [:create, :update] do
		doorkeeper_authorize! :kiosk
	end

	# GET /api/events
	#
	def index
		kiosk_ids = current_company.kiosks.pluck(:id)
		@events = Event

		params_filters{ |key, values|
			case key
					
			when :kiosk_id
				kiosk_id = params_array_to_integers(values)[0]

				return forbidden unless current_company.valid_kiosk?(kiosk_id)
				kiosk_ids = kiosk_id if kiosk_id

			when :start_date
				start_date = params_extract_date(values, 'start_date')

				@events = @events.where("created_at >= '#{start_date}'")

			when :end_date
				end_date = params_extract_date(values, 'end_date')

				@events = @events.where("created_at <= '#{end_date}'")

			end
		}

		@events = @events.where(kiosk_id: kiosk_ids)

		params_sort_by{ |key, order|
			case key
			when :created_at
				@events = @events.order("events.created_at #{order}")

			end
		}

		meta = {}
		
		params_pagination(max_limit: 30){ |limit, offset|
			meta[:total] = total = @events.count
			
			@events = offset >= total ? 
				@events.none :
				@events.limit(limit).offset(offset).order(:id)
		}
		
		@events = @events.all

		meta = nil unless meta.present?
		
		render json: @events, each_serializer: EventSerializer, meta: meta
	end
	
	# GET /api/events/:id
	#
	def show
		@event = Event.where(id: params[:id].to_i).take

		return forbidden unless current_company.valid_kiosk?(@event&.kiosk_id)
		return not_found unless @event
		
		render json: @event
	end
	
	# POST /api/events
	#
	def create
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)
		end

		@event = build_params(Event.new)
		return unless @event

		@event.save

		recipient_user = current_company.users.first

		@event.kiosk.send_alerts(current_event: @event, recipient_user: recipient_user)
		
		render json: @event
	end
	
	# PUT /api/events/:id
	#
	def update
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)
		end

		@event = Event.where(id: params[:id].to_i).take

		return forbidden unless current_company.valid_kiosk?(@event&.kiosk_id)
		return not_found unless @event
			
		return unless build_params(@event)
		
		@event.save
		
		render json: @event
	end
	
	private
	
		def safe_params
			@safe_params ||= params.require(:event).permit(
				:value,
				:choice_id,
				:kiosk_id
			)
		end
		
		def build_params(event)
			event_params = safe_params

			if event.new_record?
				kiosk_id = event_params[:kiosk_id].to_i
				raise ApplicationController::InvalidParameter.new(:kiosk_id) unless 
					kiosk_id > 0 and current_kiosk = Kiosk.where(id: kiosk_id).take

				event.kiosk = current_kiosk
				
				return forbidden unless current_company.valid_kiosk?(kiosk_id)

				last_event, * = current_kiosk.events.order(created_at: :desc).all
				event = last_event.dup if last_event

				event.choice_id = nil

				event.value = event_params[:value] if 
					event_params.has_key?(:value)

				case event.value
				when Event::VALUE_EXCELLENT
					event.increment(:cumulative_total_excellent, 1)
				when Event::VALUE_AVERAGE
					event.increment(:cumulative_total_average, 1)
				when Event::VALUE_BAD
					event.increment(:cumulative_total_bad, 1)
				when Event::VALUE_AWFUL
					event.increment(:cumulative_total_awful, 1)
				end

				event.answer_type = event.select_type
				
			end
				
			event.choice_id = event_params[:choice_id] if 
				event_params.has_key?(:choice_id)
				
			event.valid?
			
			event
		end
end
