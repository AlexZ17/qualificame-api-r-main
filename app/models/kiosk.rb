class Kiosk < ApplicationRecord
	belongs_to :company
	has_many :events, dependent: :destroy
	has_many :reports, dependent: :destroy
	has_many :questions, dependent: :destroy
	has_many :alerts, dependent: :destroy

	attr_accessor :total_excellent, :total_average, :total_bad, :total_awful, :result, :result_tag, :total_events

	def build_report(start_datetime=Time.zone.now.beginning_of_day, end_datetime=Time.zone.now.end_of_day)
		
		day_start_event, day_end_event = get_limits(start_datetime:start_datetime, end_datetime:end_datetime)

		indexed_events, result, result_tag, total_events, * = Event.get_totals(first_event: day_start_event, last_event: day_end_event)

		self.total_excellent = indexed_events[Event::VALUE_EXCELLENT]
		self.total_average   = indexed_events[Event::VALUE_AVERAGE]
		self.total_bad       = indexed_events[Event::VALUE_BAD]
		self.total_awful     = indexed_events[Event::VALUE_AWFUL]
		
		self.total_events = total_events

		self.result = result
		self.result_tag = result_tag

		return [ indexed_events, result, result_tag ]
	end

	def get_limits(start_datetime:, end_datetime:Time.zone.now.end_of_day, get_extended:false)
		# REPORTES start_datetime, end_datetime => [ start_event, end_event ]
		# KISKOS start_datetime=Time.zone.now.beginning_of_week, end_datetime=Time.zone.now.end_of_day => [ start_event, end_event ]
		# ALERTAS, extended, start_datetime=Time.zone.now.beginning_of_week, end_datetime=Time.zone.now.end_of_day => [ first_event, previous_event, last_event, start_event, end_event ]
		events = []
		if get_extended
			extended_datetime = Time.zone.now.beginning_of_week
			all_events = self.events.where(created_at: extended_datetime..end_datetime).order(:created_at).all
			some_events = all_events.where(created_at: start_datetime..end_datetime)

			first_event, *, previous_event, last_event = all_events

			if !all_events.empty? && all_events.size == 1
				last_event = previous_event = first_event

			elsif !all_events.empty? && all_events.size == 2
				last_event = previous_event
				previous_event = first_event

			end

			events += [ first_event, previous_event, last_event ]

		else
			last_event = self.events.where("created_at < '#{start_datetime}'").order(created_at: :desc).limit(1).last
			prev_limit = last_event ? last_event.created_at : start_datetime
			some_events = self.events.where(created_at: prev_limit..end_datetime).order(:created_at).all
		end


		start_event, *, end_event = some_events

		if !some_events.empty? && some_events.size == 1 && start_event.created_at >= start_datetime
			end_event = start_event
		end
		
		events += [ start_event, end_event ]

		return events
	end

	def send_alerts(current_event:, recipient_user:)
		first_event, previous_event, last_event, day_start_event, day_end_event = get_limits(start_datetime:Time.zone.now.beginning_of_day, get_extended:true)

		# total positive and negative events
		*, total_events, total_positives, total_negatives = Event.get_totals(first_event: day_start_event, last_event: day_end_event)

		if total_positives == self.min_positive_events and current_event.select_type == Event::TYPE_POSITIVE
			send_alert_positive_events(recipient_user_id: recipient_user.id, total_positives: total_positives)
		end

		if total_negatives == self.max_negative_events and current_event.select_type == Event::TYPE_NEGATIVE
			send_alert_negative_events(recipient_user_id: recipient_user.id, total_negatives: total_negatives)
		end
		
		# positive and negative thresholds
		*, total_events, total_positives, _ = Event.get_totals(first_event: first_event, last_event: last_event)
		positive_percent = total_events && total_events > 0 ? ( total_positives * 100 ) / total_events : 100
		negative_percent = 100 - positive_percent

		*, previous_events, previous_positives, _ = Event.get_totals(first_event: first_event, last_event: previous_event)
		previous_positive_percent = previous_events && previous_events > 0 ? ( previous_positives * 100 ) / previous_events : 100
		previous_negative_percent = 100 - previous_positive_percent

		if previous_positive_percent < self.min_positive_percent && positive_percent >= self.min_positive_percent
			send_alert_positive_threshold(recipient_user_id: recipient_user.id, positive_percent: positive_percent)
			
		elsif previous_negative_percent < self.max_negative_percent && negative_percent >= self.max_negative_percent
			send_alert_negative_threshold(recipient_user_id: recipient_user.id, negative_percent: negative_percent)
		end
	end

	def send_alert_positive_events(recipient_user_id:, total_positives:0)
		PushNotificationsWorker.perform_async(
			:send_message, {
				title: "¡Excelente!",
				body: "Tu sucursal #{self.name} tuvo un total de #{total_positives} eventos favorables",
				user_id: recipient_user_id
			}
		)
		Alert.create(
			title: "¡Excelente!",
			body: "Tu sucursal #{self.name} tuvo un total de #{total_positives} eventos favorables",
			kiosk_id: self.id
		)
	end

	def send_alert_negative_events(recipient_user_id:, total_negatives:0)
		PushNotificationsWorker.perform_async(
			:send_message, {
				title: "¡Cuidado con esto!",
				body: "Tu sucursal #{self.name} tuvo un total de #{total_negatives} eventos desfavorables",
				user_id: recipient_user_id
			}
		)
		Alert.create(
			title: "¡Cuidado con esto!",
			body: "Tu sucursal #{self.name} tuvo un total de #{total_negatives} eventos desfavorables",
			kiosk_id: self.id
		)
	end
	
	def send_alert_positive_threshold(recipient_user_id:, positive_percent:0)
		PushNotificationsWorker.perform_async(
			:send_message, {
				title: "¡Esto hay que celebrarlo!",
				body: "Tu sucursal #{self.name} obtuvo aprobación de #{positive_percent}%",
				user_id: recipient_user_id
			}
		)
		Alert.create(
			title: "¡Esto hay que celebrarlo!",
			body: "Tu sucursal #{name} obtuvo aprobación de #{positive_percent}%",
			kiosk_id: self.id
		)
	end
	
	def send_alert_negative_threshold(recipient_user_id:, negative_percent:0)
		PushNotificationsWorker.perform_async(
			:send_message, {
				title: "¡Oops!",
				body: "Tu sucursal #{self.name} bajó a #{negative_percent}% su nivel de aprobación",
				user_id: recipient_user_id
			}
		)
		Alert.create(
			title: "¡Oops!",
			body: "Tu sucursal #{name} bajó a #{negative_percent}% su nivel de aprobación",
			kiosk_id: self.id
		)
	end


	# def send_alert(type:nil, recipient_user_id:, data:0) TODO: finish
	# 	message = case type
	# 	when Alert:: total positivo
	# 		{ title: "", body: "" }
	# 	when Alert:: total negativo
	# 		{ title: "", body: "" }
	# 	when Alert:: porcentaje positivo
	# 		{ title: "", body: "" }
	# 	when Alert:: porcentaje negativo
	# 		{ title: "", body: "" }
	# 	end

	# 	PushNotificationsWorker.perform_async(
	# 		:send_message, message + user_id: recipient_user_id
	# 	)

	# 	Alert.create( message + kiosk_id: self.id )
	# end

end
