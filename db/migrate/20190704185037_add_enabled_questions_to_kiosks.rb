class AddEnabledQuestionsToKiosks < ActiveRecord::Migration[5.2]
	def self.up
		add_column :kiosks, :enabled_questions, :boolean, default: false unless column_exists? :kiosks, :enabled_questions
	end

	def self.down
		remove_column :kiosks, :enabled_questions if column_exists? :kiosks, :enabled_questions
	end
end
