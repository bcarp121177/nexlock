# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_10_23_153318) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_invitations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "invited_by_id"
    t.string "name", null: false
    t.jsonb "roles", default: {}, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_account_invitations_on_account_id_and_email", unique: true
    t.index ["invited_by_id"], name: "index_account_invitations_on_invited_by_id"
    t.index ["token"], name: "index_account_invitations_on_token", unique: true
  end

  create_table "account_users", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.jsonb "roles", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id", "user_id"], name: "index_account_users_on_account_id_and_user_id", unique: true
  end

  create_table "accounts", force: :cascade do |t|
    t.integer "account_users_count", default: 0
    t.string "billing_email"
    t.datetime "created_at", null: false
    t.string "domain"
    t.text "extra_billing_info"
    t.string "name", null: false
    t.bigint "owner_id"
    t.boolean "personal", default: false
    t.string "subdomain"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
  end

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "action_text_embeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "fields"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind"
    t.datetime "published_at", precision: nil
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", precision: nil
    t.datetime "last_used_at", precision: nil
    t.jsonb "metadata"
    t.string "name"
    t.string "token"
    t.boolean "transient", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "action", null: false
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "from_state"
    t.jsonb "metadata", default: {}, null: false
    t.string "to_state"
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_audit_logs_on_account_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["trade_id"], name: "index_audit_logs_on_trade_id"
  end

  create_table "connected_accounts", force: :cascade do |t|
    t.string "access_token"
    t.string "access_token_secret"
    t.jsonb "auth"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "expires_at", precision: nil
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "provider"
    t.string "refresh_token"
    t.string "uid"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["owner_id", "owner_type"], name: "index_connected_accounts_on_owner_id_and_owner_type"
  end

  create_table "disputes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "opened_by_id"
    t.text "reason", null: false
    t.jsonb "resolution_data", default: {}, null: false
    t.text "resolution_notes"
    t.string "resolution_type"
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.string "status", default: "open", null: false
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_disputes_on_account_id"
    t.index ["opened_by_id"], name: "index_disputes_on_opened_by_id"
    t.index ["resolved_by_id"], name: "index_disputes_on_resolved_by_id"
    t.index ["status"], name: "index_disputes_on_status"
    t.index ["trade_id"], name: "index_disputes_on_trade_id", unique: true
    t.check_constraint "resolution_type IS NULL OR (resolution_type::text = ANY (ARRAY['release'::character varying, 'refund'::character varying, 'split'::character varying]::text[]))", name: "disputes_resolution_values"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'under_review'::character varying, 'resolved'::character varying, 'closed'::character varying]::text[])", name: "disputes_status_values"
  end

  create_table "document_signatures", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "docuseal_slug"
    t.string "docuseal_submitter_id"
    t.string "ip_address"
    t.jsonb "signature_metadata", default: {}, null: false
    t.datetime "signed_at"
    t.string "signer_email", null: false
    t.integer "signer_role", null: false
    t.bigint "trade_document_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["account_id"], name: "index_document_signatures_on_account_id"
    t.index ["docuseal_submitter_id"], name: "index_document_signatures_on_docuseal_submitter_id"
    t.index ["signed_at"], name: "index_document_signatures_on_signed_at"
    t.index ["trade_document_id", "signer_role"], name: "index_document_signatures_on_document_and_role", unique: true
    t.index ["trade_document_id"], name: "index_document_signatures_on_trade_document_id"
    t.index ["user_id"], name: "index_document_signatures_on_user_id"
  end

  create_table "escrows", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "funded_at"
    t.string "payment_intent_id"
    t.string "payment_method_id"
    t.string "provider", default: "stripe", null: false
    t.datetime "refunded_at"
    t.string "status", null: false
    t.string "stripe_checkout_session_id"
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_escrows_on_account_id"
    t.index ["payment_intent_id"], name: "index_escrows_on_payment_intent_id", unique: true, where: "(payment_intent_id IS NOT NULL)"
    t.index ["trade_id"], name: "index_escrows_on_trade_id", unique: true
  end

  create_table "evidences", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "dispute_id"
    t.string "file_url", null: false
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_evidences_on_account_id"
    t.index ["dispute_id"], name: "index_evidences_on_dispute_id"
    t.index ["file_url"], name: "index_evidences_on_file_url"
    t.index ["trade_id"], name: "index_evidences_on_trade_id"
    t.index ["user_id"], name: "index_evidences_on_user_id"
  end

  create_table "inbound_webhooks", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "items", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "category", null: false
    t.string "condition"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "trade_id"], name: "index_items_on_account_id_and_trade_id"
    t.index ["account_id"], name: "index_items_on_account_id"
    t.index ["trade_id"], name: "index_items_on_trade_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_noticed_events_on_account_id"
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_noticed_notifications_on_account_id"
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "notification_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "platform", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_notification_tokens_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "interacted_at", precision: nil
    t.jsonb "params"
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_notifications_on_account_id"
    t.index ["recipient_type", "recipient_id"], name: "index_notifications_on_recipient_type_and_recipient_id"
  end

  create_table "pay_charges", force: :cascade do |t|
    t.integer "amount", null: false
    t.integer "amount_refunded"
    t.integer "application_fee_amount"
    t.datetime "created_at", precision: nil, null: false
    t.string "currency"
    t.bigint "customer_id"
    t.jsonb "data"
    t.jsonb "metadata"
    t.jsonb "object"
    t.string "processor_id", null: false
    t.string "stripe_account"
    t.integer "subscription_id"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_charges_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.boolean "default"
    t.datetime "deleted_at", precision: nil
    t.jsonb "object"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "processor"
    t.string "processor_id"
    t.string "stripe_account"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "deleted_at"], name: "customer_owner_processor_index"
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id"
  end

  create_table "pay_merchants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.boolean "default"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "processor"
    t.string "processor_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "processor"], name: "index_pay_merchants_on_owner_type_and_owner_id_and_processor"
  end

  create_table "pay_payment_methods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.jsonb "data"
    t.boolean "default"
    t.string "payment_method_type"
    t.string "processor_id"
    t.string "stripe_account"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_payment_methods_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_subscriptions", id: :serial, force: :cascade do |t|
    t.decimal "application_fee_percent", precision: 8, scale: 2
    t.datetime "created_at", precision: nil
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.bigint "customer_id"
    t.jsonb "data"
    t.datetime "ends_at", precision: nil
    t.jsonb "metadata"
    t.boolean "metered"
    t.string "name", null: false
    t.jsonb "object"
    t.string "pause_behavior"
    t.datetime "pause_resumes_at"
    t.datetime "pause_starts_at"
    t.string "payment_method_id"
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status"
    t.string "stripe_account"
    t.datetime "trial_ends_at", precision: nil
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.index ["customer_id", "processor_id"], name: "index_pay_subscriptions_on_customer_id_and_processor_id", unique: true
    t.index ["metered"], name: "index_pay_subscriptions_on_metered"
    t.index ["pause_starts_at"], name: "index_pay_subscriptions_on_pause_starts_at"
  end

  create_table "pay_webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "event"
    t.string "event_type"
    t.string "processor"
    t.datetime "updated_at", null: false
  end

  create_table "payouts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "seller_id", null: false
    t.string "status", null: false
    t.bigint "trade_id", null: false
    t.string "transfer_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_payouts_on_account_id"
    t.index ["seller_id"], name: "index_payouts_on_seller_id"
    t.index ["trade_id"], name: "index_payouts_on_trade_id", unique: true
  end

  create_table "plans", force: :cascade do |t|
    t.integer "amount", default: 0, null: false
    t.string "braintree_id"
    t.boolean "charge_per_unit"
    t.string "contact_url"
    t.datetime "created_at", precision: nil, null: false
    t.string "currency"
    t.string "description"
    t.jsonb "details"
    t.string "fake_processor_id"
    t.boolean "hidden"
    t.string "interval", null: false
    t.integer "interval_count", default: 1
    t.string "lemon_squeezy_id"
    t.string "name", null: false
    t.string "paddle_billing_id"
    t.string "paddle_classic_id"
    t.string "stripe_id"
    t.integer "trial_period_days", default: 0
    t.string "unit_label"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "shipments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "carrier"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "direction"
    t.string "easypost_shipment_id"
    t.string "easypost_tracker_id"
    t.datetime "est_delivery_date"
    t.integer "insured_cents"
    t.string "label_url"
    t.datetime "shipped_at"
    t.string "status"
    t.string "tracking_number"
    t.string "tracking_url"
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "trade_id"], name: "index_shipments_on_account_id_and_trade_id"
    t.index ["account_id"], name: "index_shipments_on_account_id"
    t.index ["easypost_shipment_id"], name: "index_shipments_on_easypost_shipment_id"
    t.index ["easypost_tracker_id"], name: "index_shipments_on_easypost_tracker_id"
    t.index ["tracking_number"], name: "index_shipments_on_tracking_number"
    t.index ["trade_id"], name: "index_shipments_on_trade_id"
  end

  create_table "support_messages", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "message_id"
    t.string "sent_via", default: "web", null: false
    t.bigint "support_request_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_support_messages_on_author_type_and_author_id"
    t.index ["message_id"], name: "index_support_messages_on_message_id"
    t.index ["support_request_id"], name: "index_support_messages_on_support_request_id"
    t.check_constraint "sent_via::text = ANY (ARRAY['web'::character varying, 'email'::character varying]::text[])", name: "support_messages_sent_via_values"
  end

  create_table "support_requests", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "closed_at"
    t.bigint "closed_by_id"
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "opened_by_id"
    t.string "request_type", default: "general", null: false
    t.string "status", default: "open", null: false
    t.string "subject", null: false
    t.bigint "trade_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_support_requests_on_account_id"
    t.index ["closed_by_id"], name: "index_support_requests_on_closed_by_id"
    t.index ["email"], name: "index_support_requests_on_email"
    t.index ["opened_by_id"], name: "index_support_requests_on_opened_by_id"
    t.index ["status"], name: "index_support_requests_on_status"
    t.index ["trade_id"], name: "index_support_requests_on_trade_id"
    t.check_constraint "email IS NOT NULL OR opened_by_id IS NOT NULL", name: "support_requests_contact_required"
    t.check_constraint "request_type::text = ANY (ARRAY['general'::character varying, 'dispute'::character varying, 'question'::character varying]::text[])", name: "support_requests_request_type_values"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'responded'::character varying, 'closed'::character varying]::text[])", name: "support_requests_status_values"
  end

  create_table "trade_documents", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "document_type", default: 0, null: false
    t.string "docuseal_document_url"
    t.string "docuseal_submission_id"
    t.string "docuseal_template_id"
    t.datetime "expires_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "signed_document_url"
    t.integer "status", default: 0, null: false
    t.string "title"
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_trade_documents_on_account_id"
    t.index ["docuseal_submission_id"], name: "index_trade_documents_on_docuseal_submission_id"
    t.index ["status"], name: "index_trade_documents_on_status"
    t.index ["trade_id", "document_type"], name: "index_trade_documents_on_trade_id_and_document_type"
    t.index ["trade_id"], name: "index_trade_documents_on_trade_id"
  end

  create_table "trades", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "account_id", null: false
    t.datetime "buyer_agreed_at"
    t.string "buyer_city"
    t.datetime "buyer_confirmed_receipt_at"
    t.string "buyer_country", default: "US", null: false
    t.string "buyer_email"
    t.bigint "buyer_id"
    t.string "buyer_name"
    t.string "buyer_phone"
    t.datetime "buyer_signed_at"
    t.string "buyer_state"
    t.string "buyer_street1"
    t.string "buyer_street2"
    t.string "buyer_zip"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.datetime "delivered_at"
    t.string "fee_split", default: "buyer", null: false
    t.datetime "funded_at"
    t.datetime "inspection_ends_at"
    t.datetime "inspection_starts_at"
    t.integer "inspection_window_hours", default: 72, null: false
    t.string "invitation_token"
    t.boolean "locked_for_editing", default: false, null: false
    t.integer "platform_fee_cents", default: 0, null: false
    t.integer "price_cents", null: false
    t.datetime "receipt_confirmation_deadline_at"
    t.datetime "rejected_at"
    t.string "rejection_category"
    t.datetime "return_inspection_ends_at"
    t.integer "return_shipping_cost_cents"
    t.string "return_shipping_paid_by", default: "seller", null: false
    t.datetime "seller_agreed_at"
    t.string "seller_city"
    t.string "seller_country", default: "US", null: false
    t.bigint "seller_id", null: false
    t.string "seller_name"
    t.string "seller_phone"
    t.datetime "seller_signed_at"
    t.string "seller_state"
    t.string "seller_street1"
    t.string "seller_street2"
    t.string "seller_zip"
    t.datetime "shipped_at"
    t.datetime "signature_deadline_at"
    t.datetime "signature_sent_at"
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_trades_on_account_id"
    t.index ["buyer_email"], name: "index_trades_on_buyer_email"
    t.index ["buyer_id"], name: "index_trades_on_buyer_id"
    t.index ["invitation_token"], name: "index_trades_on_invitation_token", unique: true
    t.index ["locked_for_editing"], name: "index_trades_on_locked_for_editing"
    t.index ["receipt_confirmation_deadline_at"], name: "index_trades_on_receipt_confirmation_deadline_at"
    t.index ["rejection_category"], name: "index_trades_on_rejection_category"
    t.index ["seller_id"], name: "index_trades_on_seller_id"
    t.index ["signature_deadline_at"], name: "index_trades_on_signature_deadline_at"
    t.index ["state"], name: "index_trades_on_state"
    t.check_constraint "fee_split::text = ANY (ARRAY['buyer'::character varying, 'seller'::character varying, 'split'::character varying]::text[])", name: "trades_fee_split_values"
    t.check_constraint "inspection_window_hours >= 24 AND inspection_window_hours <= 168", name: "trades_inspection_window_range"
    t.check_constraint "price_cents >= 2000 AND price_cents <= 1500000", name: "trades_price_cents_range"
    t.check_constraint "return_shipping_paid_by::text = ANY (ARRAY['seller'::character varying, 'buyer'::character varying, 'split'::character varying, 'platform'::character varying]::text[])", name: "trades_return_shipping_values"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "accepted_privacy_at", precision: nil
    t.datetime "accepted_terms_at", precision: nil
    t.boolean "admin"
    t.datetime "announcements_read_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.datetime "invitation_accepted_at", precision: nil
    t.datetime "invitation_created_at", precision: nil
    t.integer "invitation_limit"
    t.datetime "invitation_sent_at", precision: nil
    t.string "invitation_token"
    t.integer "invitations_count", default: 0
    t.bigint "invited_by_id"
    t.string "invited_by_type"
    t.string "kyc_status", default: "pending", null: false
    t.string "last_name"
    t.integer "last_otp_timestep"
    t.virtual "name", type: :string, as: "(((first_name)::text || ' '::text) || (COALESCE(last_name, ''::character varying))::text)", stored: true
    t.text "otp_backup_codes"
    t.boolean "otp_required_for_login"
    t.string "otp_secret"
    t.jsonb "preferences"
    t.string "preferred_language"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.string "stripe_connect_id"
    t.string "time_zone"
    t.string "unconfirmed_email"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by_type_and_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_connect_id"], name: "index_users_on_stripe_connect_id", unique: true
  end

  add_foreign_key "account_invitations", "accounts"
  add_foreign_key "account_invitations", "users", column: "invited_by_id"
  add_foreign_key "account_users", "accounts"
  add_foreign_key "account_users", "users"
  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "audit_logs", "accounts", on_delete: :cascade
  add_foreign_key "audit_logs", "trades", on_delete: :cascade
  add_foreign_key "audit_logs", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "disputes", "accounts", on_delete: :cascade
  add_foreign_key "disputes", "trades", on_delete: :cascade
  add_foreign_key "disputes", "users", column: "opened_by_id", on_delete: :nullify
  add_foreign_key "disputes", "users", column: "resolved_by_id", on_delete: :nullify
  add_foreign_key "document_signatures", "accounts", on_delete: :cascade
  add_foreign_key "document_signatures", "trade_documents", on_delete: :cascade
  add_foreign_key "document_signatures", "users", on_delete: :nullify
  add_foreign_key "escrows", "accounts", on_delete: :cascade
  add_foreign_key "escrows", "trades", on_delete: :cascade
  add_foreign_key "evidences", "accounts", on_delete: :cascade
  add_foreign_key "evidences", "disputes", on_delete: :cascade
  add_foreign_key "evidences", "trades", on_delete: :cascade
  add_foreign_key "evidences", "users", on_delete: :cascade
  add_foreign_key "items", "accounts", on_delete: :cascade
  add_foreign_key "items", "trades", on_delete: :cascade
  add_foreign_key "pay_charges", "pay_customers", column: "customer_id"
  add_foreign_key "pay_payment_methods", "pay_customers", column: "customer_id"
  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
  add_foreign_key "payouts", "accounts", on_delete: :cascade
  add_foreign_key "payouts", "trades", on_delete: :cascade
  add_foreign_key "payouts", "users", column: "seller_id"
  add_foreign_key "shipments", "accounts", on_delete: :cascade
  add_foreign_key "shipments", "trades", on_delete: :cascade
  add_foreign_key "support_messages", "support_requests", on_delete: :cascade
  add_foreign_key "support_requests", "accounts", on_delete: :cascade
  add_foreign_key "support_requests", "trades", on_delete: :cascade
  add_foreign_key "support_requests", "users", column: "closed_by_id", on_delete: :nullify
  add_foreign_key "support_requests", "users", column: "opened_by_id", on_delete: :nullify
  add_foreign_key "trade_documents", "accounts", on_delete: :cascade
  add_foreign_key "trade_documents", "trades", on_delete: :cascade
  add_foreign_key "trades", "accounts", on_delete: :cascade
  add_foreign_key "trades", "users", column: "buyer_id"
  add_foreign_key "trades", "users", column: "seller_id"
end
