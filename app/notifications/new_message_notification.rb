class NewMessageNotification < Noticed::Event
  deliver_by :database
  deliver_by :email, mailer: 'MessageMailer', method: :new_message, if: :email_notifications_enabled?

  param :message
  param :conversation

  def message
    "New message about #{params[:conversation].trade.item.name}"
  end

  def url
    conversation_path(params[:conversation])
  end

  private

  def email_notifications_enabled?
    # For authenticated users, check their notification settings
    recipient.respond_to?(:notification_setting) && recipient.notification_setting&.email_notifications?
  end
end
