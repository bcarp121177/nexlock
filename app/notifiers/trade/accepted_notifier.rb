class Trade::AcceptedNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :accepted
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Item accepted - Payout has been initiated"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
