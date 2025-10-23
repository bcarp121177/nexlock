class Trade::FundedNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :funded
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Trade ##{trade.id} has been funded - You can now ship the item"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
