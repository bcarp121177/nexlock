class AuditLog < ApplicationRecord
  belongs_to :account
  belongs_to :trade
  belongs_to :actor, class_name: "User", optional: true

  validates :action, presence: true
end
