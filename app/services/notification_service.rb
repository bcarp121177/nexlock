class NotificationService
  class << self
    def send_trade_funded(trade)
      Rails.logger.info "TODO: Send notification - Trade #{trade.id} funded"
      # TODO: Implement notification logic
      # Could use Noticed gem, Action Mailer, push notifications, etc.
    end

    def send_item_shipped(trade)
      Rails.logger.info "TODO: Send notification - Trade #{trade.id} item shipped"
      # TODO: Implement notification logic
    end

    def send_package_delivered(trade)
      Rails.logger.info "TODO: Send notification - Trade #{trade.id} package delivered"
      # TODO: Implement notification logic
    end

    def send_item_accepted(trade)
      Rails.logger.info "TODO: Send notification - Trade #{trade.id} item accepted"
      # TODO: Implement notification logic
    end

    def send_item_rejected(trade)
      Rails.logger.info "TODO: Send notification - Trade #{trade.id} item rejected"
      # TODO: Implement notification logic
    end
  end
end
