class UserSerializer < ActiveModel::Serializer
	attributes :id, :company_id, :company_name,
		:email, :first_name, :last_name, :created_at

	def company_name
		object.company.name
	end

	def created_at
		object.created_at&.to_i
	end
end