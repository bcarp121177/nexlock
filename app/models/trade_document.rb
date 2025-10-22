class TradeDocument < ApplicationRecord
  belongs_to :account
  belongs_to :trade

  has_many :document_signatures, dependent: :destroy

  enum :status, { draft: 0, pending: 1, completed: 2, expired: 3 }, suffix: true
  enum :document_type, { trade_agreement: 0, shipping_label: 1, release_authorization: 2 }, suffix: true
end
