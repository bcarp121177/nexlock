class NotificationService
  class << self
    def send_trade_funded(trade)
      Rails.logger.info "Sending funded notification for trade #{trade.id}"
      Trade::FundedNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_item_shipped(trade)
      Rails.logger.info "Sending shipped notification for trade #{trade.id}"
      Trade::ShippedNotifier.with(trade: trade).deliver_later(trade.buyer)
    end

    def send_package_delivered(trade)
      Rails.logger.info "Sending delivered notification for trade #{trade.id}"
      Trade::DeliveredNotifier.with(trade: trade).deliver_later(trade.buyer)
    end

    def send_item_accepted(trade)
      Rails.logger.info "Sending accepted notification for trade #{trade.id}"
      Trade::AcceptedNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_item_rejected(trade)
      Rails.logger.info "Sending rejected notification for trade #{trade.id}"
      Trade::RejectedNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_return_accepted(trade)
      Rails.logger.info "Sending return accepted notification for trade #{trade.id}"
      Trade::ReturnAcceptedNotifier.with(trade: trade).deliver_later(trade.buyer)
    end

    def send_refund_processed(trade)
      Rails.logger.info "Sending refund processed notification for trade #{trade.id}"
      Trade::RefundedNotifier.with(trade: trade).deliver_later(trade.buyer)
    end
  end
end
