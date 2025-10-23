class Account < ApplicationRecord
  has_prefix_id :acct

  include Billing
  include Domains
  include Transfer
  include Types

  has_many :trades, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :shipments, dependent: :destroy
  has_many :escrows, dependent: :destroy
  has_many :payouts, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :trade_documents, dependent: :destroy
  has_many :document_signatures, dependent: :destroy
  has_many :disputes, dependent: :destroy
  has_many :evidences, dependent: :destroy
  has_many :support_requests, dependent: :destroy
end
