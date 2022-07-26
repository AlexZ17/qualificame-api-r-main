class Company < ApplicationRecord
	has_many :users, inverse_of: :company
	has_many :kiosks

	def valid_kiosk?(kiosk_id)
		return false unless kiosk_id.is_a? Integer
		
		return kiosks.pluck(:id).include?(kiosk_id)
	end

	def valid_question?(question_id)
		return false unless question_id.is_a? Integer
		
		questions = Question.where(kiosk_id: kiosks.pluck(:id)).all
		return questions.pluck(:id).include?(question_id)
	end
end
