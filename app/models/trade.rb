class Trade < ApplicationRecord
  include AASM

  attr_accessor :price_dollars

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

  SELLER_FAULT_CATEGORIES = %w[defective not_as_described wrong_item damaged].freeze
  BUYER_FAULT_CATEGORIES = %w[buyers_remorse changed_mind no_longer_wanted].freeze
  REJECTION_CATEGORIES = (SELLER_FAULT_CATEGORIES + BUYER_FAULT_CATEGORIES + %w[other]).freeze

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
  has_many :support_requests, dependent: :destroy

  has_many_attached :media
  has_one_attached :signed_agreement

  accepts_nested_attributes_for :item

  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 2000, less_than_or_equal_to: 1_500_000 }
  validates :inspection_window_hours, presence: true, numericality: { greater_than_or_equal_to: 24, less_than_or_equal_to: 168 }
  validates :fee_split, presence: true, inclusion: { in: %w[buyer seller split] }
  validates :buyer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
            if: -> { state.in?(%w[awaiting_seller_signature awaiting_buyer_signature signature_deadline_missed awaiting_funding funded shipped delivered_pending_confirmation inspection accepted released rejected return_in_transit return_delivered_pending_confirmation return_inspection returned refunded disputed resolved_release resolved_refund resolved_split]) }
  validates :return_shipping_paid_by, inclusion: { in: %w[seller buyer split platform] }
  validates :rejection_category, inclusion: { in: REJECTION_CATEGORIES }, allow_nil: true
  validates :listing_status, inclusion: { in: %w[draft published accepted expired] }
  validates :account, :seller, presence: true
  validate :buyer_and_seller_are_different
  validate :cannot_edit_if_locked

  delegate :email, to: :seller, prefix: true

  before_create :generate_invitation_token
  after_save :log_state_change, if: :saved_change_to_state?

  scope :ordered, -> { order(created_at: :desc) }
  scope :requiring_attention, -> { where(state: STATES_REQUIRING_ATTENTION) }
  scope :completed, -> { where(state: STATES_COMPLETED) }
  scope :published_listings, -> { where(listing_status: 'published') }
  scope :active_listings, -> { published_listings.where('listing_expires_at IS NULL OR listing_expires_at > ?', Time.current) }

  aasm column: :state do
    state :draft, initial: true
    state :published
    state :awaiting_seller_signature
    state :awaiting_buyer_signature
    state :signature_deadline_missed
    state :awaiting_funding
    state :funded
    state :shipped
    state :delivered_pending_confirmation
    state :inspection
    state :accepted
    state :released
    state :rejected
    state :return_in_transit
    state :return_delivered_pending_confirmation
    state :return_inspection
    state :returned
    state :refunded
    state :disputed
    state :resolved_release
    state :resolved_refund
    state :resolved_split

    event :publish_listing do
      transitions from: :draft,
                  to: :published,
                  guard: :can_publish?,
                  after: :mark_published
    end

    event :unpublish_listing do
      transitions from: :published,
                  to: :draft,
                  after: :mark_unpublished
    end

    event :send_for_signature do
      transitions from: [:draft, :published],
                  to: :awaiting_seller_signature,
                  guard: [:can_send_for_signature?, :buyer_info_complete?],
                  after: [:lock_for_editing, :create_signature_document]
    end

    event :seller_signs do
      transitions from: :awaiting_seller_signature,
                  to: :awaiting_buyer_signature,
                  after: [:record_seller_signature, :notify_buyer_to_sign, :notify_buyer_signature_needed]
    end

    event :buyer_signs do
      transitions from: :awaiting_buyer_signature,
                  to: :awaiting_funding,
                  after: [:record_buyer_signature, :finalize_agreement, :notify_funding_required]
    end

    event :signature_deadline_expired do
      transitions from: [:awaiting_seller_signature, :awaiting_buyer_signature],
                  to: :signature_deadline_missed,
                  after: [:cancel_signature_process, :notify_deadline_missed]
    end

    event :restart_signature_process do
      transitions from: :signature_deadline_missed,
                  to: :draft,
                  after: :unlock_for_editing
    end

    event :cancel_signature_request do
      transitions from: [:awaiting_seller_signature, :awaiting_buyer_signature],
                  to: :draft,
                  after: [:cancel_docuseal_submission, :unlock_for_editing]
    end

    event :agree do
      transitions from: :draft, to: :awaiting_funding, guard: :both_parties_agreed?, after: :schedule_ship_by_deadline
    end

    event :mark_funded do
      transitions from: :awaiting_funding, to: :funded, after: %i[notify_seller schedule_ship_by_timer]
    end

    event :mark_shipped do
      transitions from: :funded, to: :shipped, after: %i[subscribe_to_tracking notify_buyer_shipped]
    end

    event :mark_delivered do
      transitions from: :shipped, to: :delivered_pending_confirmation, after: %i[set_receipt_confirmation_deadline notify_buyer_delivered]
    end

    event :confirm_receipt do
      transitions from: :delivered_pending_confirmation, to: :inspection, after: %i[start_inspection_window notify_receipt_confirmed]
    end

    event :auto_confirm_receipt do
      transitions from: :delivered_pending_confirmation, to: :inspection, after: %i[log_auto_confirmation start_inspection_window]
    end

    event :accept do
      transitions from: :inspection, to: :accepted, guard: :within_inspection_window?, after: %i[trigger_payout notify_seller_accepted]
    end

    event :mark_released do
      transitions from: :accepted, to: :released, after: :close_trade
    end

    event :reject do
      transitions from: :inspection, to: :rejected, guard: :has_evidence?, after: %i[generate_return_label notify_seller_rejected]
    end

    event :mark_return_shipped do
      transitions from: :rejected, to: :return_in_transit, after: :notify_return_shipped
    end

    event :mark_return_delivered do
      transitions from: :return_in_transit, to: :return_delivered_pending_confirmation, after: :notify_return_delivered
    end

    event :confirm_return_receipt do
      transitions from: :return_delivered_pending_confirmation, to: :return_inspection, after: %i[start_return_inspection_window notify_return_receipt_confirmed]
    end

    event :accept_return do
      transitions from: :return_inspection, to: :returned, after: :notify_return_accepted
    end

    event :reject_return do
      transitions from: :return_inspection, to: :disputed, after: :notify_return_rejected
    end

    event :refund do
      transitions from: %i[returned disputed], to: :refunded, after: %i[process_refund notify_refund_processed]
    end

    event :open_dispute do
      transitions from: %i[
        draft
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
        return_delivered_pending_confirmation
        return_inspection
      ], to: :disputed
    end

    event :resolve_with_release do
      transitions from: :disputed, to: :resolved_release, after: %i[execute_release_payout notify_dispute_resolved_release]
    end

    event :resolve_with_refund do
      transitions from: :disputed, to: :resolved_refund, after: %i[execute_refund notify_dispute_resolved_refund]
    end

    event :resolve_with_split do
      transitions from: :disputed, to: :resolved_split, after: %i[execute_split_payout notify_dispute_resolved_split]
    end
  end

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

  def buyer_email_address
    buyer&.email || buyer_email
  end

  def both_parties_agreed?
    true
  end

  def can_send_for_signature?
    item.present? && price_cents.present?
  end

  def seller_address_complete?
    [seller_name, seller_street1, seller_city,
     seller_state, seller_zip, seller_country].all?(&:present?)
  end

  def buyer_address_complete?
    [buyer_name, buyer_street1, buyer_city,
     buyer_state, buyer_zip, buyer_country].all?(&:present?)
  end

  def within_inspection_window?
    inspection_ends_at.present? && Time.current < inspection_ends_at
  end

  def has_evidence?
    evidences.exists?
  end

  def determine_return_cost_responsibility(category)
    case category
    when *SELLER_FAULT_CATEGORIES
      'seller'
    when *BUYER_FAULT_CATEGORIES
      'buyer'
    else
      return_shipping_paid_by
    end
  end

  def calculate_refund_amount
    refund = price_cents

    if return_shipping_paid_by == 'buyer' && return_shipping_cost_cents.present?
      refund -= return_shipping_cost_cents
    elsif return_shipping_paid_by == 'split' && return_shipping_cost_cents.present?
      refund -= (return_shipping_cost_cents / 2.0).round
    end

    [refund, 0].max
  end

  # Listing-related methods
  def can_publish?
    draft? && item.present? && price_cents.present? && listing_status == 'draft'
  end

  def buyer_info_complete?
    buyer_email.present? &&
      buyer_name.present? &&
      buyer_street1.present? &&
      buyer_city.present? &&
      buyer_state.present? &&
      buyer_zip.present? &&
      buyer_country.present?
  end

  def listing_url
    return nil unless invitation_token.present?
    host = ENV.fetch("APP_HOST", "localhost:3000")
    Rails.application.routes.url_helpers.public_listing_url(invitation_token, host: host)
  end

  def unique_visitors_count
    Ahoy::Visit.where(
      visit_token: Ahoy::Event.where(name: 'listing_view')
                               .where("properties->>'trade_id' = ?", id.to_s)
                               .select(:visit_token)
    ).distinct.count
  end

  def listing_views_count
    Ahoy::Event.where(name: 'listing_view')
               .where("properties->>'trade_id' = ?", id.to_s)
               .count
  end

  def published?
    listing_status == 'published'
  end

  private

  def generate_invitation_token
    loop do
      self.invitation_token = SecureRandom.urlsafe_base64(32)
      break unless Trade.exists?(invitation_token: invitation_token)
    end
  end

  def buyer_and_seller_are_different
    if buyer_id.present? && seller_id.present?
      errors.add(:base, "Buyer and seller must be different users") if buyer_id == seller_id
    end

    if buyer_email.present? && seller
      errors.add(:base, "Buyer and seller must be different users") if buyer_email.downcase == seller.email.downcase
    end
  end

  def cannot_edit_if_locked
    if locked_for_editing? &&
       changed.any? { |attr| !%w[state updated_at locked_for_editing seller_signed_at buyer_signed_at signature_deadline_at signature_sent_at delivered_at funded_at shipped_at].include?(attr) }
      errors.add(:base, "Trade is locked during signature process")
    end
  end

  def lock_for_editing
    update_column(:locked_for_editing, true)
  end

  def unlock_for_editing
    update_column(:locked_for_editing, false)
  end

  def create_signature_document
    result = TradeDocumentService.create_trade_agreement(self)
    unless result[:success]
      Rails.logger.error "Failed to create signature document: #{result[:error]}"
      raise "Failed to create signature document: #{result[:error]}"
    end
    Rails.logger.info "Trade #{id} signature document created"
  end

  def mark_published
    update_columns(published_at: Time.current, listing_status: 'published')
    Rails.logger.info "Trade #{id} published as listing"
  end

  def mark_unpublished
    update_columns(published_at: nil, listing_status: 'draft')
    Rails.logger.info "Trade #{id} unpublished"
  end

  def record_seller_signature
    update_column(:seller_signed_at, Time.current)
    Rails.logger.info "Seller signed trade #{id}"
  end

  def record_buyer_signature
    update_column(:buyer_signed_at, Time.current)
    Rails.logger.info "Buyer signed trade #{id}"
  end

  def finalize_agreement
    unlock_for_editing
    Rails.logger.info "Both parties signed trade #{id}, trade unlocked"
  end

  def notify_buyer_to_sign
    Rails.logger.info "Notifying buyer to sign trade #{id}"
  end

  def cancel_signature_process
    trade_document = trade_documents.trade_agreement_document_type.where.not(status: [:completed, :expired]).last
    if trade_document
      trade_document.update!(status: :expired)
    end
    unlock_for_editing
    Rails.logger.info "Signature process cancelled for trade #{id}"
  end

  def notify_deadline_missed
    Rails.logger.info "Signature deadline missed for trade #{id}"
  end

  def cancel_docuseal_submission
    trade_document = trade_documents.trade_agreement_document_type.where.not(status: [:completed, :expired]).last
    if trade_document
      trade_document.update!(status: :expired)
    end
    Rails.logger.info "DocuSeal submission cancelled for trade #{id}"
  end

  def schedule_ship_by_deadline
  end

  def notify_seller
    NotificationService.send_trade_funded(self)
  end

  def notify_buyer_shipped
    NotificationService.send_item_shipped(self)
  end

  def notify_buyer_delivered
    NotificationService.send_package_delivered(self)
  end

  def notify_seller_accepted
    NotificationService.send_item_accepted(self)
  end

  def notify_seller_rejected
    NotificationService.send_item_rejected(self)
  end

  def notify_return_accepted
    NotificationService.send_return_accepted(self)
  end

  def notify_refund_processed
    NotificationService.send_refund_processed(self)
  end

  def notify_receipt_confirmed
    NotificationService.send_receipt_confirmed(self)
  end

  def notify_return_shipped
    NotificationService.send_return_shipped(self)
  end

  def notify_return_delivered
    NotificationService.send_return_delivered(self)
  end

  def notify_return_receipt_confirmed
    NotificationService.send_return_receipt_confirmed(self)
  end

  def notify_return_rejected
    NotificationService.send_return_rejected(self)
  end

  def notify_dispute_resolved_release
    NotificationService.send_dispute_resolved_release(self)
  end

  def notify_dispute_resolved_refund
    NotificationService.send_dispute_resolved_refund(self)
  end

  def notify_dispute_resolved_split
    NotificationService.send_dispute_resolved_split(self)
  end

  def notify_buyer_signature_needed
    Rails.logger.info "*** notify_buyer_signature_needed called for trade #{id}, buyer present: #{buyer.present?}"
    NotificationService.send_buyer_signature_needed(self)
  end

  def notify_funding_required
    NotificationService.send_funding_required(self)
  end

  def notify_signature_deadline_reminder
    NotificationService.send_signature_deadline_reminder(self)
  end

  def schedule_ship_by_timer
  end

  def subscribe_to_tracking
    shipment = shipments.where(direction: 'forward').order(created_at: :desc).first
    return unless shipment&.tracking_number

    Rails.logger.info "Subscribed to tracking for #{shipment.tracking_number}"
  end

  def set_receipt_confirmation_deadline
    deadline = Time.current + ENV.fetch('RECEIPT_CONFIRMATION_HOURS', '48').to_i.hours
    update!(receipt_confirmation_deadline_at: deadline)
    Rails.logger.info "Receipt confirmation deadline set for #{deadline}"
  end

  def start_inspection_window
    update!(
      buyer_confirmed_receipt_at: Time.current,
      inspection_starts_at: Time.current,
      inspection_ends_at: Time.current + inspection_window_hours.hours
    )
    Rails.logger.info "Inspection window started, ends at #{inspection_ends_at}"
  end

  def log_auto_confirmation
    AuditLog.create!(
      trade: self,
      action: 'auto_confirmed_receipt',
      metadata: {
        delivered_at: delivered_at,
        auto_confirmed_at: Time.current,
        reason: 'Buyer did not confirm within 48 hours of delivery'
      }
    )
    Rails.logger.info "Auto-confirmed receipt for trade #{id}"
  end

  def trigger_payout
    result = StripeService.create_payout(self)

    unless result[:success]
      Rails.logger.error "Payout failed for trade #{id}: #{result[:error]}"
      # Don't raise - we don't want to rollback the state transition
      # The payout can be retried manually or via admin interface
      return
    end

    Rails.logger.info "Payout triggered for trade #{id}: #{result[:transfer].id}"
  end

  def close_trade
  end

  def generate_return_label
    Rails.logger.info "Generating return label for trade #{id}"

    result = EasyPostService.create_return_shipment_label(self)

    unless result[:success]
      Rails.logger.error "Return label generation failed: #{result[:error]}"
      raise "Failed to generate return label: #{result[:error]}"
    end

    shipments.create!(
      account: account,
      carrier: result[:shipment][:carrier],
      tracking_number: result[:shipment][:tracking_number],
      easypost_shipment_id: result[:shipment][:easypost_shipment_id],
      label_url: result[:shipment][:label_url],
      tracking_url: result[:shipment][:tracking_url],
      easypost_tracker_id: result[:shipment][:easypost_tracker_id],
      est_delivery_date: result[:shipment][:est_delivery_date],
      direction: 'return',
      status: 'pre_transit'
    )

    Rails.logger.info "Return label created: #{result[:shipment][:tracking_number]}"
  end

  def start_return_inspection_window
    hours = ENV.fetch('RETURN_INSPECTION_HOURS', '48').to_i
    deadline = Time.current + hours.hours
    update!(return_inspection_ends_at: deadline)
    Rails.logger.info "Seller has #{hours} hours to inspect returned item (until #{deadline})"
  end

  def hold_seller_inspection
    Rails.logger.info "Seller has 48 hours to inspect returned item"
  end

  def process_refund
    result = StripeService.create_refund(self)
    unless result[:success]
      Rails.logger.error "Refund failed: #{result[:error]}"
      raise "Refund processing failed: #{result[:error]}"
    end
    Rails.logger.info "Refund processed: #{result[:refund].id}"
  end

  def execute_release_payout
    result = StripeService.create_payout(self)
    unless result[:success]
      Rails.logger.error "Dispute release payout failed: #{result[:error]}"
      raise "Payout failed: #{result[:error]}"
    end
    Rails.logger.info "Dispute resolved - payout to seller: #{result[:transfer].id}"
  end

  def execute_refund
    process_refund
  end

  def execute_split_payout
    return unless dispute.present?

    seller_percentage = dispute.resolution_data['seller_percentage'] || 50

    seller_amount = (price_cents * seller_percentage / 100.0).round
    buyer_refund = price_cents - seller_amount

    if fee_split == 'buyer'
      buyer_refund -= platform_fee_cents
    elsif fee_split == 'seller'
      seller_amount -= platform_fee_cents
    elsif fee_split == 'split'
      half_fee = (platform_fee_cents / 2.0).round
      buyer_refund -= half_fee
      seller_amount -= half_fee
    end

    seller_amount = [seller_amount, 0].max
    buyer_refund = [buyer_refund, 0].max

    Rails.logger.info "Split payout: Seller gets $#{seller_amount / 100.0}, Buyer gets $#{buyer_refund / 100.0}"
  end

  def log_state_change
    audit_logs.create!(
      account: account,
      actor_id: Current.user&.id,
      action: "state_change",
      from_state: state_before_last_save,
      to_state: state,
      metadata: { timestamp: Time.current }
    )
  end

  # Signature workflow helper methods
  def signed_agreement_url
    signed_agreement.attached? ? signed_agreement.url : trade_documents.completed_status.trade_agreement_document_type.last&.signed_document_url
  end

  def signature_progress
    doc = trade_documents.pending_status.last || trade_documents.completed_status.last
    return { seller: false, buyer: false } unless doc

    {
      seller: doc.document_signatures.seller_signer_role.first&.signed_at.present?,
      buyer: doc.document_signatures.buyer_signer_role.first&.signed_at.present?
    }
  end

  def can_download_agreement?
    signed_agreement_url.present? && (awaiting_funding? || funded? || shipped? || delivered_pending_confirmation? || inspection? || accepted?)
  end

  def active_signature_document
    trade_documents.pending_status.trade_agreement_document_type.last
  end
end
