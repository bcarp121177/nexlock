class Evidence < ApplicationRecord
  belongs_to :account
  belongs_to :trade
  belongs_to :user
  belongs_to :dispute, optional: true

  validates :file_url, presence: true
end
