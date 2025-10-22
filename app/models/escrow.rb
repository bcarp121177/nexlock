class Escrow < ApplicationRecord
  belongs_to :account
  belongs_to :trade

  enum :status, {
    pending: "pending",
    held: "held",
    released: "released",
    refunded: "refunded"
  }, suffix: true

  validates :provider, :amount_cents, :status, presence: true
end
