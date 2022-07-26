class Question < ApplicationRecord
	TYPE_POSITIVE   = 1
	TYPE_NEGATIVE   = 2
	
	belongs_to :kiosk
	has_many :choices, dependent: :destroy
end
