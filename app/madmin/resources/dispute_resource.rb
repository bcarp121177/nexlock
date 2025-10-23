class DisputeResource < Madmin::Resource
  menu parent: "Trades"

  # Attributes
  attribute :id, form: false
  attribute :trade
  attribute :account
  attribute :opened_by
  attribute :resolved_by
  attribute :status
  attribute :reason
  attribute :resolution_data
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :evidences, form: false

  def self.display_name(record)
    "Dispute ##{record.id} - Trade ##{record.trade_id}"
  end

  def self.default_sort_column
    "created_at"
  end

  def self.default_sort_direction
    "desc"
  end
end
