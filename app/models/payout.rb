class Payout < ApplicationRecord
  belongs_to :account
  belongs_to :trade
  belongs_to :seller, class_name: "User"

  enum status: {
    pending: "pending",
    processing: "processing",
    paid: "paid",
    failed: "failed"
  }, _suffix: true

  validates :amount_cents, :status, presence: true
end
