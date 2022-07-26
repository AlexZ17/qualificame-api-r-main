class CreateMobileDevices < ActiveRecord::Migration[5.2]
  def change
    create_table :mobile_devices do |t|
      t.string :token, limit: 22, null: false
      t.integer :platform_type, limit: 1
      t.boolean :disabled
      t.references :user, index: true

      t.timestamps
    end

    add_index :mobile_devices, [:token, :platform_type], unique: true
  end
end
