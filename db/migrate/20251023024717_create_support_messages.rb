class CreateSupportMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :support_messages do |t|
      t.references :support_request, null: false, foreign_key: { on_delete: :cascade }, index: true

      # Polymorphic author - can be User (authenticated) or nil (anonymous email)
      t.string :author_type
      t.bigint :author_id

      t.text :body, null: false
      t.string :sent_via, null: false, default: "web" # web or email
      t.string :message_id # Email Message-ID header for threading

      t.timestamps

      t.index [:author_type, :author_id]
      t.index :message_id
      t.check_constraint "sent_via IN ('web', 'email')", name: "support_messages_sent_via_values"
    end
  end
end
