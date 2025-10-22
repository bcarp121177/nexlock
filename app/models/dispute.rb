class Dispute < ApplicationRecord
  belongs_to :account
  belongs_to :trade
  belongs_to :opened_by, class_name: "User", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  has_many :evidences, dependent: :destroy

  enum status: {
    open: "open",
    under_review: "under_review",
    resolved: "resolved",
    closed: "closed"
  }, _suffix: true

  validates :reason, :status, presence: true
end
