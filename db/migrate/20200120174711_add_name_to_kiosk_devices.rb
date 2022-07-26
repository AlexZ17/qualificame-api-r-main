class AddNameToKioskDevices < ActiveRecord::Migration[5.2]
  def change
    add_column :kiosk_devices, :name, :string
  end
end
