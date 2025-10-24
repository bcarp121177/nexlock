class AddSellerContactEmailToTrades < ActiveRecord::Migration[8.1]
  def change
    add_column :trades, :seller_contact_email, :string
  end
end
