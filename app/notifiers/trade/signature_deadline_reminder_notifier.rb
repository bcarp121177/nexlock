class Trade::SignatureDeadlineReminderNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :signature_deadline_reminder
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Urgent: Agreement expires in 24 hours - Trade ##{trade.id}"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
