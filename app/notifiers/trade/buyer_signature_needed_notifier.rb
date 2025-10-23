class Trade::BuyerSignatureNeededNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :buyer_signature_needed
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Agreement ready for your signature - Trade ##{trade.id}"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
