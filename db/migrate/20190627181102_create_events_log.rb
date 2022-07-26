class CreateEventsLog < ActiveRecord::Migration[5.2]
	def self.up
		add_column :events, :cumulative_total_excellent, :integer, default: 0 unless column_exists? :events, :cumulative_total_excellent
		add_column :events, :cumulative_total_average, :integer, default: 0 unless column_exists? :events, :cumulative_total_average
		add_column :events, :cumulative_total_bad, :integer, default: 0 unless column_exists? :events, :cumulative_total_bad
		add_column :events, :cumulative_total_awful, :integer, default: 0 unless column_exists? :events, :cumulative_total_awful
	end

	def self.down
		remove_column :events, :cumulative_total_excellent if column_exists? :events, :cumulative_total_excellent
		remove_column :events, :cumulative_total_average if column_exists? :events, :cumulative_total_average
		remove_column :events, :cumulative_total_bad if column_exists? :events, :cumulative_total_bad
		remove_column :events, :cumulative_total_awful if column_exists? :events, :cumulative_total_awful
	end
end
