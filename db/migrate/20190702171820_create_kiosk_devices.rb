class CreateKioskDevices < ActiveRecord::Migration[5.2]
	def change
		create_table :kiosk_devices do |t|
			t.string  :uuid,       null: false
			t.integer :status
			t.integer :kiosk_id

			t.timestamps
		end
	end
end
