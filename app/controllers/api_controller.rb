class ApiController < ApplicationController
	# before_action :doorkeeper_authorize!, unless: :user_signed_in?

	def current_user
		@current_user ||= if doorkeeper_token
							User.where(id: doorkeeper_token.resource_owner_id).take
						# else
						# 	warden.authenticate(scope: :user)
						end
	end

	def current_company
		current_user.company
	end

	def scope
		doorkeeper_token.scopes.to_s
	end
end
