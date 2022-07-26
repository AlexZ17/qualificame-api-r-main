class CreateEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :events do |t|
      t.integer :value
      t.integer :answer_type
      t.integer :choice_id
      t.integer :kiosk_id

      t.timestamps
    end
  end
end
