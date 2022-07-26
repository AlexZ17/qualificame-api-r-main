class AddFirstAndLastNameToUsers < ActiveRecord::Migration[5.2]
	def up
		add_column :users, :first_name, :string unless column_exists? :users, :first_name
		add_column :users, :last_name, :string unless column_exists? :users, :last_name
		remove_column :users, :name if column_exists? :users, :name
	end
	def down
		remove_column :users, :first_name if column_exists? :users, :first_name
		remove_column :users, :last_name if column_exists? :users, :last_name
		add_column :users, :name, :string unless column_exists? :users, :name
	end
end
