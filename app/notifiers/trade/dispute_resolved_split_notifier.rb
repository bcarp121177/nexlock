class Trade::DisputeResolvedSplitNotifier < ApplicationNotifier
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = :to_websocket
  end

  deliver_by :email do |config|
    config.mailer = "TradeMailer"
    config.method = :dispute_resolved_split
  end

  param :trade

  def trade
    params[:trade]
  end

  def message
    "Dispute resolved - Partial refund will be processed"
  end

  def url
    Rails.application.routes.url_helpers.trade_path(trade)
  end
end
