class CreateTradeWorkflowTables < ActiveRecord::Migration[8.0]
  def change
    create_table :trades do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :buyer, foreign_key: { to_table: :users }
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :state, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.integer :inspection_window_hours, null: false, default: 72
      t.string :fee_split, null: false, default: "buyer"
      t.integer :platform_fee_cents, null: false, default: 0
      t.datetime :buyer_agreed_at
      t.datetime :seller_agreed_at
      t.datetime :funded_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :inspection_starts_at
      t.datetime :inspection_ends_at
      t.datetime :buyer_confirmed_receipt_at
      t.datetime :receipt_confirmation_deadline_at
      t.datetime :accepted_at
      t.datetime :rejected_at
      t.datetime :cancelled_at
      t.string :buyer_email
      t.string :invitation_token
      t.string :buyer_name
      t.string :buyer_street1
      t.string :buyer_street2
      t.string :buyer_city
      t.string :buyer_state
      t.string :buyer_zip
      t.string :buyer_country, null: false, default: "US"
      t.string :buyer_phone
      t.string :seller_name
      t.string :seller_street1
      t.string :seller_street2
      t.string :seller_city
      t.string :seller_state
      t.string :seller_zip
      t.string :seller_country, null: false, default: "US"
      t.string :seller_phone
      t.string :return_shipping_paid_by, null: false, default: "seller"
      t.string :rejection_category
      t.integer :return_shipping_cost_cents
      t.datetime :signature_deadline_at
      t.datetime :signature_sent_at
      t.datetime :seller_signed_at
      t.datetime :buyer_signed_at
      t.boolean :locked_for_editing, null: false, default: false
      t.timestamps
    end

    add_index :trades, :state
    add_index :trades, :invitation_token, unique: true
    add_index :trades, :buyer_email
    add_index :trades, :receipt_confirmation_deadline_at
    add_index :trades, :rejection_category
    add_index :trades, :signature_deadline_at
    add_index :trades, :locked_for_editing

    add_check_constraint :trades, "price_cents BETWEEN 2000 AND 1500000", name: "trades_price_cents_range"
    add_check_constraint :trades, "inspection_window_hours BETWEEN 24 AND 168", name: "trades_inspection_window_range"
    add_check_constraint :trades, "fee_split IN ('buyer', 'seller', 'split')", name: "trades_fee_split_values"
    add_check_constraint :trades, "return_shipping_paid_by IN ('seller', 'buyer', 'split', 'platform')", name: "trades_return_shipping_values"

    create_table :items do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :description, null: false
      t.string :category, null: false
      t.string :condition
      t.integer :price_cents, null: false
      t.timestamps
    end

    add_index :items, [:account_id, :trade_id]

    create_table :shipments do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, foreign_key: { on_delete: :cascade }
      t.string :carrier
      t.string :tracking_number
      t.integer :insured_cents
      t.string :status
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.string :direction
      t.string :easypost_shipment_id
      t.string :label_url
      t.string :tracking_url
      t.string :easypost_tracker_id
      t.datetime :est_delivery_date
      t.timestamps
    end

    add_index :shipments, :tracking_number
    add_index :shipments, :easypost_shipment_id
    add_index :shipments, :easypost_tracker_id
    add_index :shipments, [:account_id, :trade_id]

    create_table :escrows do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false, default: "stripe"
      t.string :payment_intent_id
      t.string :payment_method_id
      t.integer :amount_cents, null: false
      t.string :status, null: false
      t.datetime :funded_at
      t.timestamps
    end

    add_index :escrows, :payment_intent_id, unique: true, where: "payment_intent_id IS NOT NULL"

    create_table :payouts do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.string :transfer_id
      t.string :status, null: false
      t.timestamps
    end

    create_table :audit_logs do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, foreign_key: { on_delete: :cascade }
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :action, null: false
      t.string :from_state
      t.string :to_state
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :audit_logs, :action

    create_table :trade_documents do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, foreign_key: { on_delete: :cascade }
      t.integer :document_type, null: false, default: 0
      t.string :title
      t.string :docuseal_submission_id
      t.string :docuseal_template_id
      t.integer :status, null: false, default: 0
      t.string :signed_document_url
      t.string :docuseal_document_url
      t.jsonb :metadata, null: false, default: {}
      t.datetime :completed_at
      t.datetime :expires_at
      t.timestamps
    end

    add_index :trade_documents, :docuseal_submission_id
    add_index :trade_documents, :status
    add_index :trade_documents, [:trade_id, :document_type]

    create_table :document_signatures do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade_document, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :signer_email, null: false
      t.integer :signer_role, null: false
      t.string :docuseal_submitter_id
      t.string :docuseal_slug
      t.datetime :signed_at
      t.string :ip_address
      t.string :user_agent
      t.jsonb :signature_metadata, null: false, default: {}
      t.timestamps
    end

    add_index :document_signatures, :docuseal_submitter_id
    add_index :document_signatures, :signed_at
    add_index :document_signatures, [:trade_document_id, :signer_role], unique: true, name: "index_document_signatures_on_document_and_role"

    create_table :disputes do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :opened_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :resolved_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.text :reason, null: false
      t.string :status, null: false, default: "open"
      t.datetime :resolved_at
      t.string :resolution_type
      t.text :resolution_notes
      t.jsonb :resolution_data, null: false, default: {}
      t.timestamps
    end

    add_index :disputes, :status
    add_check_constraint :disputes, "status IN ('open', 'under_review', 'resolved', 'closed')", name: "disputes_status_values"
    add_check_constraint :disputes, "resolution_type IS NULL OR resolution_type IN ('release', 'refund', 'split')", name: "disputes_resolution_values"

    create_table :evidences do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :dispute, foreign_key: { on_delete: :cascade }
      t.references :trade, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :file_url, null: false
      t.text :description
      t.timestamps
    end

    add_index :evidences, :file_url
  end
end
