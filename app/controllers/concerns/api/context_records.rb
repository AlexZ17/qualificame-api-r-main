module Api::ContextRecords
	extend ActiveSupport::Concern

	included do
		before_action do |controller|
			# current_user = controller.send(:current_user)
			
			# case current_user&.role
			# when User::ROLE_ALUMNO
			# 	next unauthorized unless @student = current_user.user_record = 
			# 		Alumno.by_contacto(current_user.contacto_id).take

			# when User::ROLE_PROFESOR
			# 	next unauthorized unless @professor = current_user.user_record = 
			# 		Profesor.by_contacto(current_user.contacto_id).take

			# when User::ROLE_FAMILIAR
			# 	next unauthorized unless @relative = current_user.user_record = 
			# 		Familiar.by_contacto(current_user.contacto_id).take

			# when User::ROLE_ADMIN
			# 	next unauthorized unless @admin_user = current_user.admin_user = 
			# 		AdminUser.by_contacto(current_user.contacto_id).take

			# end
		end
	end

	class_methods do

		def load_context_records_for(records)

			records.each{ |method, klass| 
				attr_reader method 
				private method
			}

			before_action do |controller|
				records.each{ |method, klass|

					method_id = params["#{method}_id".to_sym].to_i
					if method_id > 0 and record = klass.where(id: method_id).take
						instance_variable_set("@#{method}", record)
					end
				}
			end

		end

	end

	private

		# attr_reader :professor, :admin_user, :relative, :student

end