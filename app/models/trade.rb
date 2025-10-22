class Trade < ApplicationRecord
  STATES_REQUIRING_ATTENTION = %w[
    awaiting_seller_signature
    awaiting_buyer_signature
    signature_deadline_missed
    awaiting_funding
    funded
    shipped
    delivered_pending_confirmation
    inspection
    rejected
    return_in_transit
    disputed
  ].freeze

  STATES_COMPLETED = %w[
    accepted
    released
    returned
    refunded
    resolved_release
    resolved_refund
    resolved_split
  ].freeze

  belongs_to :account
  belongs_to :buyer, class_name: "User", optional: true
  belongs_to :seller, class_name: "User"

  has_one :item, dependent: :destroy
  has_one :escrow, dependent: :destroy
  has_one :payout, dependent: :destroy
  has_one :dispute, dependent: :destroy

  has_many :shipments, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :trade_documents, dependent: :destroy
  has_many :document_signatures, through: :trade_documents
  has_many :evidences, dependent: :destroy

  has_many_attached :media

  validates :price_cents, presence: true
  validates :state, presence: true
  validates :seller, presence: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :requiring_attention, -> { where(state: STATES_REQUIRING_ATTENTION) }
  scope :completed, -> { where(state: STATES_COMPLETED) }

  def price
    price_cents.to_f / 100.0
  end

  def formatted_state
    state.to_s.tr("_", " ").titleize
  end

  def counterparty_for(user)
    return seller if buyer == user
    return buyer if seller == user

    nil
  end
end
