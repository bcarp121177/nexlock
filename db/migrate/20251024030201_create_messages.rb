class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :sender_type, null: false
      t.references :sender_user, null: true, foreign_key: { to_table: :users }
      t.string :sender_email, null: false
      t.text :body, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :messages, [:conversation_id, :created_at]
    add_index :messages, :read_at
  end
end
