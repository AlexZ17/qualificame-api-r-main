class CreateReports < ActiveRecord::Migration[5.2]
  def change
    create_table :reports do |t|
      t.datetime :start_datetime
      t.datetime :end_datetime
      t.integer :total_excellent
      t.integer :total_average
      t.integer :total_bad
      t.integer :total_awful
      t.decimal :result
      t.string :result_tag
      t.integer :kiosk_id

      t.timestamps
    end
  end
end
