class ChoiceSerializer < ActiveModel::Serializer
	attributes :id, :description, :question_id, :active, :created_at

	def created_at
		object.created_at&.to_i
	end
end
