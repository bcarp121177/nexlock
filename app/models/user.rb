class User < ApplicationRecord
  has_prefix_id :user

  include Accounts
  include Agreements
  include Authenticatable
  include Mentions
  include Notifiable
  include Searchable
  include Theme

  has_one_attached :avatar
  has_person_name

  has_many :trades_as_buyer, class_name: "Trade", foreign_key: :buyer_id, dependent: :nullify
  has_many :trades_as_seller, class_name: "Trade", foreign_key: :seller_id, dependent: :restrict_with_error
  has_many :payouts, foreign_key: :seller_id, dependent: :nullify
  has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify
  has_many :evidences, dependent: :destroy
  has_many :opened_disputes, class_name: "Dispute", foreign_key: :opened_by_id, dependent: :nullify
  has_many :resolved_disputes, class_name: "Dispute", foreign_key: :resolved_by_id, dependent: :nullify
  has_many :document_signatures, dependent: :nullify
  has_many :opened_support_requests, class_name: "SupportRequest", foreign_key: :opened_by_id, dependent: :nullify
  has_many :closed_support_requests, class_name: "SupportRequest", foreign_key: :closed_by_id, dependent: :nullify

  validates :avatar, resizable_image: true
  validates :name, presence: true
  validates :kyc_status, inclusion: { in: %w[pending verified rejected] }

  # Auto-link trades after user registration
  after_create :link_buyer_trades

  def stripe_account_active?
    stripe_connect_id.present? && kyc_status == "verified"
  end

  def can_receive_payouts?
    stripe_account_active?
  end

  private

  # Link trades where user was invited as buyer by email
  def link_buyer_trades
    trades = Trade.where(
      buyer_email: email.downcase.strip,
      buyer_id: nil
    )

    count = trades.count
    return if count.zero?

    # Update all matching trades to link to this user
    trades.update_all(buyer_id: id)

    Rails.logger.info "Linked #{count} anonymous trade(s) to user #{id} (#{email})"
  end
end
