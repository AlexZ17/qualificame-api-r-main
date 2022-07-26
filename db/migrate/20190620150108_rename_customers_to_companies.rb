class RenameCustomersToCompanies < ActiveRecord::Migration[5.2]
	def self.up
		rename_table :customers, :companies
		rename_column :kiosks, :customer_id, :company_id
		rename_column :users, :customer_id, :company_id
	end

	def self.down
		rename_table :companies, :customers
		rename_column :kiosks, :company_id, :customer_id
		rename_column :users, :company_id, :customer_id
	end
end
