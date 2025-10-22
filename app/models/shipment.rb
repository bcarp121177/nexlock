class Shipment < ApplicationRecord
  belongs_to :account
  belongs_to :trade

  enum :direction, { forward: "forward", return: "return" }, suffix: true

  validates :direction, presence: true
end
