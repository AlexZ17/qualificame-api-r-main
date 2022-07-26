class KioskSerializer < ActiveModel::Serializer
	include Qualificame::Params::Serializer
	attributes :id, :name, :welcome_message, :phone, :email, :address, :company_id, :enabled_questions,
		:max_negative_percent, :min_positive_percent, :max_negative_events, :min_positive_events,
		:total_excellent, :total_average, :total_bad, :total_awful,
		:total_events, :result, :result_tag, :created_at, :beginning_of_day, :end_of_day

	def total_excellent
		object.total_excellent.to_i
	end

	def total_average
		object.total_average.to_i
	end

	def total_bad
		object.total_bad.to_i
	end

	def total_awful	
		object.total_awful.to_i
	end

	def total_events
		object.total_events.to_i
	end

	def created_at
		object.created_at&.to_i
	end
end