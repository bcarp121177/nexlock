class Trade::DeliveredNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :delivered
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Your package has been delivered - Please confirm receipt"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
