class NotificationService
  class << self
    def send_buyer_signature_needed(trade)
      Rails.logger.info "Sending buyer signature needed notification for trade #{trade.id}"

      # Only send if buyer user exists, otherwise they'll get DocuSeal email
      if trade.buyer.present?
        Trade::BuyerSignatureNeededNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.info "Skipping buyer signature notification - buyer not registered yet"
      end
    end

    def send_signature_deadline_reminder(trade)
      Rails.logger.info "Sending signature deadline reminder for trade #{trade.id}"
      # Send to whoever hasn't signed yet
      if trade.awaiting_buyer_signature? && trade.buyer.present?
        Trade::SignatureDeadlineReminderNotifier.with(trade: trade).deliver_later(trade.buyer)
      elsif trade.awaiting_buyer_signature? && !trade.buyer.present?
        Rails.logger.info "Skipping signature reminder - buyer not registered yet"
      elsif trade.awaiting_seller_signature?
        Trade::SignatureDeadlineReminderNotifier.with(trade: trade).deliver_later(trade.seller)
      end
    end

    def send_funding_required(trade)
      Rails.logger.info "Sending funding required notification for trade #{trade.id}"

      # Only send if buyer user exists
      if trade.buyer.present?
        Trade::FundingRequiredNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.info "Skipping funding notification - buyer not registered yet"
      end
    end

    def send_trade_funded(trade)
      Rails.logger.info "Sending funded notification for trade #{trade.id}"
      Trade::FundedNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_item_shipped(trade)
      Rails.logger.info "Sending shipped notification for trade #{trade.id}"

      if trade.buyer.present?
        Trade::ShippedNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send shipped notification - buyer not found for trade #{trade.id}"
      end
    end

    def send_package_delivered(trade)
      Rails.logger.info "Sending delivered notification for trade #{trade.id}"

      if trade.buyer.present?
        Trade::DeliveredNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send delivered notification - buyer not found for trade #{trade.id}"
      end
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

      if trade.buyer.present?
        Trade::ReturnAcceptedNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send return accepted notification - buyer not found for trade #{trade.id}"
      end
    end

    def send_refund_processed(trade)
      Rails.logger.info "Sending refund processed notification for trade #{trade.id}"

      if trade.buyer.present?
        Trade::RefundedNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send refund notification - buyer not found for trade #{trade.id}"
      end
    end

    def send_receipt_confirmed(trade)
      Rails.logger.info "Sending receipt confirmed notification for trade #{trade.id}"
      Trade::ReceiptConfirmedNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_return_shipped(trade)
      Rails.logger.info "Sending return shipped notification for trade #{trade.id}"
      Trade::ReturnShippedNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_return_delivered(trade)
      Rails.logger.info "Sending return delivered notification for trade #{trade.id}"
      Trade::ReturnDeliveredNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_return_receipt_confirmed(trade)
      Rails.logger.info "Sending return receipt confirmed notification for trade #{trade.id}"

      if trade.buyer.present?
        Trade::ReturnReceiptConfirmedNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send return receipt notification - buyer not found for trade #{trade.id}"
      end
    end

    def send_return_rejected(trade)
      Rails.logger.info "Sending return rejected notification for trade #{trade.id}"

      if trade.buyer.present?
        Trade::ReturnRejectedNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send return rejected notification - buyer not found for trade #{trade.id}"
      end
    end

    def send_dispute_resolved_release(trade)
      Rails.logger.info "Sending dispute resolved (release) notification for trade #{trade.id}"
      # Notify both parties
      if trade.buyer.present?
        Trade::DisputeResolvedReleaseNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send dispute resolved notification to buyer - buyer not found for trade #{trade.id}"
      end
      Trade::DisputeResolvedReleaseNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_dispute_resolved_refund(trade)
      Rails.logger.info "Sending dispute resolved (refund) notification for trade #{trade.id}"
      # Notify both parties
      if trade.buyer.present?
        Trade::DisputeResolvedRefundNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send dispute resolved refund notification to buyer - buyer not found for trade #{trade.id}"
      end
      Trade::DisputeResolvedRefundNotifier.with(trade: trade).deliver_later(trade.seller)
    end

    def send_dispute_resolved_split(trade)
      Rails.logger.info "Sending dispute resolved (split) notification for trade #{trade.id}"
      # Notify both parties
      if trade.buyer.present?
        Trade::DisputeResolvedSplitNotifier.with(trade: trade).deliver_later(trade.buyer)
      else
        Rails.logger.warn "Cannot send dispute resolved split notification to buyer - buyer not found for trade #{trade.id}"
      end
      Trade::DisputeResolvedSplitNotifier.with(trade: trade).deliver_later(trade.seller)
    end
  end
end
