class AlertSerializer < ActiveModel::Serializer
	attributes :id, :kiosk_id, :title, :body, :read, :created_at

	def created_at
		object.created_at&.to_i
	end
end
