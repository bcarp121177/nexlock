class Trade::ReturnReceiptConfirmedNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :return_receipt_confirmed
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Seller confirmed return receipt - Inspection in progress"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
