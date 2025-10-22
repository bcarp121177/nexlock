class Shipment < ApplicationRecord
  belongs_to :account
  belongs_to :trade

  enum direction: { forward: "forward", return: "return" }, _suffix: true

  validates :direction, presence: true
end
