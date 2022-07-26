class CreateTableAlerts < ActiveRecord::Migration[5.2]
  def change
    create_table :alerts do |t|
      t.integer :kiosk_id
      t.string :title
      t.text :body
      t.boolean :read, default: false

      t.timestamps
    end
  end
end
