class CreateChoices < ActiveRecord::Migration[5.2]
  def change
    create_table :choices do |t|
      t.text :description
      t.integer :question_id
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
