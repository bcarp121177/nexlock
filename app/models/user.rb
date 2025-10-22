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

  validates :avatar, resizable_image: true
  validates :name, presence: true
  validates :kyc_status, inclusion: { in: %w[pending verified rejected] }

  def stripe_account_active?
    stripe_connect_id.present? && kyc_status == "verified"
  end

  def can_receive_payouts?
    stripe_account_active?
  end
end
