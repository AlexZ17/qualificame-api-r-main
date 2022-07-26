class QuestionSerializer < ActiveModel::Serializer
	attributes :id, :question_type, :description, :kiosk_id, :created_at

	def created_at
		object.created_at&.to_i
	end
end
