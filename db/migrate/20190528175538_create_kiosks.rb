class CreateKiosks < ActiveRecord::Migration[5.2]
  def change
    create_table :kiosks do |t|
      t.string :name
      t.text :welcome_message
      t.string :phone, :limit => 15
      t.string :email
      t.text :address
      t.float :max_negative_percent
      t.float :min_positive_percent
      t.integer :max_negative_events
      t.integer :min_positive_events
      t.integer :customer_id

      t.timestamps
    end
  end
end
