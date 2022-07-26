class Api::EventsAggregationsController < ApiController
	include Qualificame::Params
	before_action only: [:index] do
		doorkeeper_authorize! :admin
	end

	# GET /api/kiosks/:kiosk_id/event_aggregations
	#
	def index
		return forbidden unless kiosk_id = params[:kiosk_id].to_i and kiosk_id > 0

		@events = ::Event

		start_datetime = Time.zone.now.beginning_of_day
		end_datetime = Time.zone.now.end_of_day

		kiosk = Kiosk.where(id: params[:kiosk_id].to_i).take


		if (kiosk && kiosk.beginning_of_day && kiosk.end_of_day)
			start_datetime = Time.zone.now.change({ 
				hour: kiosk.beginning_of_day.hour,
				min: kiosk.beginning_of_day.min,
				sec: kiosk.beginning_of_day.sec
			})
			end_datetime = Time.zone.now.change({ 
				hour: kiosk.end_of_day.hour,
				min: kiosk.end_of_day.min,
				sec: kiosk.end_of_day.sec,
				day: kiosk.beginning_of_day > kiosk.end_of_day ? Time.zone.now.day + 1 : Time.zone.now.day
			})
		end



		params_filters{ |key, values|
			case key
					
			when :value
				@events = @events.where("value = '#{values[0]}'")

			when :start_date
				start_date = values[0] != 'undefined' ? values[0] : start_datetime

				@events = @events.where("events.created_at >= '#{start_date}'")

			when :end_date
				end_date = values[0] != 'undefined' ? values[0] : end_datetime

				@events = @events.where("events.created_at <= '#{end_date}'")

			end
		}

		@events = @events.where(kiosk_id: kiosk_id)


		@events = @events.select('choice_id AS id', 'description', 'active', 'COUNT(*) AS total').joins("INNER JOIN choices ON events.choice_id = choices.id").group('choice_id').order('3 DESC').all

		render json: @events, each_serializer:EventAggregationSerializer
	end

end