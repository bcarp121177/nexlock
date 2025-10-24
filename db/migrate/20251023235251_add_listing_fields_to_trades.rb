class AddListingFieldsToTrades < ActiveRecord::Migration[8.1]
  def change
    add_column :trades, :published_at, :datetime
    add_column :trades, :listing_status, :string, default: 'draft', null: false
    add_column :trades, :buyer_viewed_at, :datetime
    add_column :trades, :listing_expires_at, :datetime
    add_column :trades, :view_count, :integer, default: 0, null: false

    add_index :trades, :listing_status
    add_index :trades, :published_at
  end
end
