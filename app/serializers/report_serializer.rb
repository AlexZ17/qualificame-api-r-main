class ReportSerializer < ActiveModel::Serializer
	attributes :id, :start_datetime, :end_datetime, :kiosk_id,
		:total_excellent, :total_average, :total_bad, :total_awful,
		:result, :result_tag

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
		object.events&.count
	end

	def created_at
		object.created_at&.to_i
	end
end