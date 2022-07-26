class User < ApplicationRecord
	KIOSK = 'kiosk'
	ADMIN = 'admin'

	include SerializerOptions
	# Include default devise modules. Others available are:
	# :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
	devise :database_authenticatable, :registerable,
 		   :recoverable, :rememberable, :validatable
	belongs_to :company, autosave: true
	has_many :mobile_devices, inverse_of: :user, dependent: :destroy
end
