class AddConnectFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_connect_id, :string
    add_column :users, :kyc_status, :string, null: false, default: "pending"

    add_index :users, :stripe_connect_id, unique: true
  end
end
