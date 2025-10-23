class SupportRequestResource < Madmin::Resource
  menu parent: "Support", position: 5

  # Attributes
  attribute :id, form: false
  attribute :subject
  attribute :email
  attribute :status
  attribute :account
  attribute :trade
  attribute :opened_by
  attribute :closed_by
  attribute :closed_at, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :support_messages, form: false

  def self.display_name(record)
    "##{record.id} - #{record.subject}"
  end

  def self.default_sort_column
    "created_at"
  end

  def self.default_sort_direction
    "desc"
  end

  def self.scope(scope)
    scope.includes(:account, :trade, :opened_by)
  end
end
