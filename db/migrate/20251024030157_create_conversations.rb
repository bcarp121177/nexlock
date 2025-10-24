class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :trade, null: false, foreign_key: true
      t.references :seller, polymorphic: true, null: false
      t.references :buyer_user, null: true, foreign_key: { to_table: :users }
      t.string :buyer_email, null: false
      t.string :buyer_token, null: false
      t.string :status, default: 'active', null: false

      t.timestamps
    end

    add_index :conversations, :buyer_token, unique: true
    add_index :conversations, :buyer_email
    add_index :conversations, :status
  end
end
