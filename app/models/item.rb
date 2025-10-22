class Item < ApplicationRecord
  belongs_to :account
  belongs_to :trade

  validates :name, :description, :category, :price_cents, presence: true
end
