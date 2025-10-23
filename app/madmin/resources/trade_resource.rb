class TradeResource < Madmin::Resource
  menu parent: "Trades", position: 1

  # Attributes
  attribute :id, form: false
  attribute :account
  attribute :buyer
  attribute :seller
  attribute :state
  attribute :price_cents
  attribute :currency
  attribute :fee_split
  attribute :platform_fee_cents
  attribute :inspection_window_hours
  attribute :buyer_email
  attribute :rejection_category
  attribute :return_shipping_paid_by
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :item, form: false
  attribute :escrow, form: false
  attribute :payout, form: false
  attribute :dispute, form: false
  attribute :shipments, form: false
  attribute :evidences, form: false
  attribute :audit_logs, form: false

  def self.display_name(record)
    "Trade ##{record.id} - #{record.item&.name || 'Unknown'}"
  end

  def self.default_sort_column
    "created_at"
  end

  def self.default_sort_direction
    "desc"
  end
end
