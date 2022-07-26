class CreateQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :questions do |t|
      t.integer :question_type
      t.text :description
      t.integer :kiosk_id

      t.timestamps
    end
    
    add_index(:questions, [:question_type, :kiosk_id], :unique => true, :name => 'unique_question_type_by_kiosk_id')
  end
end
