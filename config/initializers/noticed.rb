# Configures Noticed to be scoped by account
ActiveSupport.on_load :noticed_event do
  belongs_to :account, optional: true

  # Set account association from params
  def self.with(params)
    account = params.delete(:account) || Current.account
    record = params.delete(:record)

    # Instantiate Noticed::Event with account:belongs_to
    new(account: account, params: params, record: record)
  end

  def recipient_attributes_for(recipient)
    account_id = account&.id || recipient&.personal_account&.id
    super.merge(account_id: account_id)
  end
end

ActiveSupport.on_load :noticed_notification do
  belongs_to :account, optional: true
  delegate :message, to: :event
end
