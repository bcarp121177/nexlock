class SupportRequest < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :trade, optional: true
  belongs_to :opened_by, class_name: "User", optional: true
  belongs_to :closed_by, class_name: "User", optional: true

  has_many :support_messages, dependent: :destroy

  enum :status, {
    open: "open",
    responded: "responded",
    closed: "closed"
  }, suffix: true

  enum :request_type, {
    general: "general",
    dispute: "dispute",
    question: "question"
  }, suffix: true

  validates :subject, presence: true
  validates :status, presence: true
  validates :request_type, presence: true
  validate :contact_info_present

  scope :for_account, ->(account) { where(account: account) }
  scope :for_trade, ->(trade) { where(trade: trade) }
  scope :by_status, ->(status) { where(status: status) }
  scope :ordered, -> { order(created_at: :desc) }

  def contact_email
    email.presence || opened_by&.email
  end

  def contact_name
    opened_by&.name || email&.split("@")&.first&.titleize || "Anonymous"
  end

  def latest_message
    support_messages.order(created_at: :desc).first
  end

  def close!(closed_by_user)
    update!(
      status: "closed",
      closed_by: closed_by_user,
      closed_at: Time.current
    )
  end

  def reopen!
    update!(
      status: "open",
      closed_by: nil,
      closed_at: nil
    )
  end

  private

  def contact_info_present
    if email.blank? && opened_by_id.blank?
      errors.add(:base, "Either email or opened_by must be present")
    end
  end
end
