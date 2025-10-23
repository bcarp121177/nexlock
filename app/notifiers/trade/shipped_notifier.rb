class Trade::ShippedNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :shipped
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Your item has been shipped - Track your package"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
