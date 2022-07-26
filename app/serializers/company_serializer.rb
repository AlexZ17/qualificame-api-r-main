class CompanySerializer < ActiveModel::Serializer
	attributes :id, :name, :created_at

	def created_at
		object.created_at&.to_i
	end
end
