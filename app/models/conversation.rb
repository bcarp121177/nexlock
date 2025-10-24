class Conversation < ApplicationRecord
  STATUSES = %w[active archived converted_to_buyer].freeze

  belongs_to :trade
  belongs_to :seller, polymorphic: true
  belongs_to :buyer_user, class_name: "User", optional: true
  has_many :messages, dependent: :destroy

  validates :buyer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :buyer_token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  before_validation :generate_buyer_token, on: :create

  scope :active, -> { where(status: 'active') }
  scope :for_user, ->(user) {
    where(seller: user)
      .or(where(buyer_user: user))
  }
  scope :for_trade, ->(trade) { where(trade: trade) }
  scope :ordered, -> { order(updated_at: :desc) }

  def unread_count_for(user)
    if user == seller
      messages.where(sender_type: 'buyer', read_at: nil).count
    else
      messages.where(sender_type: 'seller', read_at: nil).count
    end
  end

  def last_message
    messages.order(created_at: :desc).first
  end

  def mark_as_converted!
    update!(status: 'converted_to_buyer')
  end

  def participant_name_for(user)
    if user == seller
      buyer_user&.name || buyer_email
    else
      seller.try(:name) || "Seller"
    end
  end

  private

  def generate_buyer_token
    self.buyer_token ||= loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless Conversation.exists?(buyer_token: token)
    end
  end
end
