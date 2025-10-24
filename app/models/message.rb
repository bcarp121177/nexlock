class Message < ApplicationRecord
  SENDER_TYPES = %w[seller buyer].freeze

  belongs_to :conversation
  belongs_to :sender_user, class_name: "User", optional: true

  validates :sender_type, inclusion: { in: SENDER_TYPES }
  validates :sender_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :body, presence: true, length: { maximum: 10_000 }

  after_create :touch_conversation
  after_create :send_notification

  scope :ordered, -> { order(created_at: :asc) }
  scope :unread, -> { where(read_at: nil) }

  def mark_as_read!
    update!(read_at: Time.current) if read_at.nil?
  end

  def sender_name
    sender_user&.name || sender_email.split('@').first.titleize
  end

  def from_seller?
    sender_type == 'seller'
  end

  def from_buyer?
    sender_type == 'buyer'
  end

  private

  def touch_conversation
    conversation.touch
  end

  def send_notification
    # Determine the recipient based on sender type
    recipient = sender_type == 'seller' ? conversation.buyer_user : conversation.seller

    # Send notification to authenticated user if they exist
    if recipient
      NewMessageNotification.with(message: self, conversation: conversation).deliver(recipient)
    end

    # Also send email to anonymous buyer if they don't have an account
    if sender_type == 'seller' && conversation.buyer_user.nil?
      MessageMailer.new_message_anonymous(self).deliver_later
    end
  end
end
