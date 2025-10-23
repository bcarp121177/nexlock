class CreateSupportRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :support_requests do |t|
      t.string :subject, null: false
      t.string :email # For anonymous support requests
      t.string :status, null: false, default: "open"

      # Optional associations
      t.references :account, foreign_key: { on_delete: :cascade }, index: true
      t.references :trade, foreign_key: { on_delete: :cascade }, index: true
      t.references :opened_by, foreign_key: { to_table: :users, on_delete: :nullify }, index: true
      t.references :closed_by, foreign_key: { to_table: :users, on_delete: :nullify }, index: true

      t.datetime :closed_at
      t.timestamps

      t.index :status
      t.index :email
      t.check_constraint "status IN ('open', 'responded', 'closed')", name: "support_requests_status_values"
      t.check_constraint "email IS NOT NULL OR opened_by_id IS NOT NULL", name: "support_requests_contact_required"
    end
  end
end
