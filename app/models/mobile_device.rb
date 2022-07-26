class MobileDevice < ApplicationRecord
	TYPE_IOS = 1
	TYPE_GCM = 2
	TYPE_EXPO = 3

	belongs_to :user, inverse_of: :mobile_devices

	class InvalidDeviseType < StandardError
	end

	def enabled?
		disabled == false
	end

	def expo?
		platform_type == TYPE_EXPO
	end

	def ios?
		platform_type == TYPE_IOS
	end

	def gcm?
		platform_type == TYPE_GCM
	end

	def build_message(title:, body:, sound: 'default', badge: nil, **data)
		case platform_type
		
		when TYPE_EXPO
			{ 
				title: title, 
				body: body,
				sound: sound, 
				data: data 
			
			}.tap{ |message|
				message[:badge] = badge if badge 
			}
		
		else raise InvalidDeviseType
		end
	end

end
