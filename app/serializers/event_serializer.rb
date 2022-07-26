class EventSerializer < ActiveModel::Serializer
	include Qualificame::Params::Serializer

	attributes :id, :value, :answer_type, :choice_id, :kiosk_id, :created_at

	extra_attributes :choice_description

	def created_at
		object.created_at&.to_i
	end

	def	choice_description
		object.choice&.description
	end
end
