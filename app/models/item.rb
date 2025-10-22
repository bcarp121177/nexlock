class Item < ApplicationRecord
  belongs_to :account
  belongs_to :trade

  CATEGORIES = %w[guitar bass drums keyboard amplifier effects other].freeze
  CONDITIONS = %w[new like_new excellent good fair poor].freeze

  validates :name, :description, :category, :price_cents, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :condition, inclusion: { in: CONDITIONS }
end
