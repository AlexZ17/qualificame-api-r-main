class AddFieldsToKiosks < ActiveRecord::Migration[5.2]
  def change
    add_column :kiosks, :beginning_of_day, :time
    add_column :kiosks, :end_of_day, :time
  end
end
