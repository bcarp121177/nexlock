class TradeService
  class << self
    def create_trade(account:, seller:, buyer_email:, item_params:, trade_params:)
      normalized_email = buyer_email.to_s.strip.downcase
      buyer = User.find_by(email: normalized_email)
      

      if buyer && buyer.id == seller.id
        return { trade: nil, error: I18n.t("trades.service.errors.same_party", default: "Buyer and seller cannot be the same user.") }
      end

      if seller.email.casecmp?(normalized_email)
        return { trade: nil, error: I18n.t("trades.service.errors.same_party", default: "Buyer and seller cannot be the same user.") }
      end

      price_cents = trade_params[:price_cents].to_i
      if price_cents <= 0
        return { trade: nil, error: I18n.t("trades.service.errors.price_required", default: "Enter a valid price."), errors: { price_cents: [I18n.t("trades.service.errors.price_required", default: "Enter a valid price.")] } }
      end

      trade_attributes = trade_params.merge(price_cents: price_cents, inspection_window_hours: trade_params[:inspection_window_hours].to_i, currency: trade_params[:currency] || "USD")
      
      trade = account.trades.new(trade_attributes)
      trade.fee_split = trade.fee_split.presence || "buyer"
      trade.seller = seller
      trade.buyer = buyer
      trade.buyer_email = normalized_email
      trade.state = "draft"
      trade.return_shipping_paid_by ||= "seller"
      trade.seller_agreed_at = Time.current

      if item_params.present?
        trade.build_item(item_params)
        trade.item.account = account
        trade.item.price_cents = trade.price_cents
      end

      fees = calculate_platform_fee(trade.price_cents, fee_split: trade.fee_split)
      trade.platform_fee_cents = fees[:total_fee]

      if trade.save
        AuditLog.create!(account: trade.account, trade: trade, actor: seller, action: "trade_created", to_state: "draft")
        { trade: trade }
      else
        { trade: nil, error: trade.errors.full_messages.join(", "), errors: trade.errors.messages }
      end
    end

    def send_to_buyer(trade)
      unless trade.draft?
        return { success: false, error: I18n.t("trades.actions.errors.invalid_state", default: "Can only send draft trades to buyer.") }
      end

      if defined?(EmailService)
        EmailService.send_buyer_invitation(trade)
      end

      AuditLog.create!(
        account: trade.account,
        trade: trade,
        actor: Current.user,
        action: "invitation_sent",
        metadata: {
          buyer_email: trade.buyer_email,
          timestamp: Time.current
        }
      )

      { success: true, message: I18n.t("trades.actions.invitation.sent", default: "Invitation sent to buyer.") }
    end

    def record_agreement(trade, user)
      return { success: false, error: I18n.t("trades.actions.errors.not_party", default: "You are not a party to this trade.") } unless party?(trade, user)

      mark_agreed(trade, user)

      AuditLog.create!(
        account: trade.account,
        trade: trade,
        actor: user,
        action: "agreed",
        metadata: {
          ip: Current.ip_address,
          user_agent: Current.user_agent,
          timestamp: Time.current,
          party: trade.buyer_id == user.id ? "buyer" : "seller"
        }
      )

      if trade.buyer_agreed_at.present? && trade.seller_agreed_at.present?
        if trade.may_agree?
          trade.agree!
          AuditLog.create!(account: trade.account, trade: trade, actor: user, action: "state_change", from_state: "draft", to_state: "awaiting_funding")
        end
        { success: true, message: I18n.t("trades.actions.agreement.ready", default: "Both parties agreed.") }
      else
        { success: true, message: I18n.t("trades.actions.agreement.recorded", default: "Agreement recorded. Waiting for the other party.") }
      end
    end

    def mark_shipped(trade, carrier:, tracking_number:)
      return { success: false, error: I18n.t("trades.actions.errors.invalid_state", default: "Trade must be funded before shipping.") } unless trade.may_mark_shipped?
      return { success: false, error: I18n.t("trades.actions.errors.tracking_required", default: "Tracking number is required.") } if tracking_number.blank?

      shipment = nil

      Trade.transaction do
        shipment = trade.shipments.create!(
          account: trade.account,
          carrier: carrier.presence || "Unknown",
          tracking_number: tracking_number,
          direction: "forward",
          status: "in_transit",
          shipped_at: Time.current,
          insured_cents: trade.price_cents
        )

        trade.mark_shipped!
      end

      { success: true, shipment: shipment }
    rescue => e
      { success: false, error: e.message }
    end

    def mark_delivered(trade)
      return { success: false, error: I18n.t("trades.actions.errors.invalid_state", default: "Trade must be shipped before marking delivered.") } unless trade.may_mark_delivered?

      trade.mark_delivered!

      AuditLog.create!(
        account: trade.account,
        trade: trade,
        actor: Current.user,
        action: "state_change",
        from_state: "shipped",
        to_state: "delivered_pending_confirmation"
      )

      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def confirm_receipt(trade)
      return { success: false, error: I18n.t("trades.actions.errors.invalid_state", default: "Trade is not awaiting receipt confirmation.") } unless trade.may_confirm_receipt?

      trade.confirm_receipt!

      AuditLog.create!(
        account: trade.account,
        trade: trade,
        actor: Current.user,
        action: "state_change",
        from_state: "delivered_pending_confirmation",
        to_state: "inspection"
      )

      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def accept_delivery(trade)
      return { success: false, error: I18n.t("trades.actions.errors.invalid_state", default: "Trade cannot be accepted in current state.") } unless trade.may_accept?

      trade.accept!

      AuditLog.create!(
        account: trade.account,
        trade: trade,
        actor: Current.user,
        action: "state_change",
        from_state: "inspection",
        to_state: "accepted"
      )

      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def reject_delivery(trade, reason_category:, reason_text:)
      return { success: false, error: I18n.t("trades.actions.errors.reason_required", default: "Reason is required") } if reason_category.blank?
      return { success: false, error: I18n.t("trades.actions.errors.reason_required", default: "Reason is required") } if reason_text.blank?

      unless Trade::REJECTION_CATEGORIES.include?(reason_category)
        return { success: false, error: I18n.t("trades.actions.errors.invalid_reason", default: "Invalid rejection reason.") }
      end

      trade.update!(
        rejection_category: reason_category,
        return_shipping_paid_by: trade.determine_return_cost_responsibility(reason_category)
      )

      trade.evidences.create!(account: trade.account, user: Current.user, file_url: "text://rejection", description: reason_text)
      trade.reject!

      AuditLog.create!(
        account: trade.account,
        trade: trade,
        actor: Current.user,
        action: "state_change",
        from_state: "inspection",
        to_state: "rejected",
        metadata: {
          reason_category: reason_category,
          reason_text: reason_text
        }
      )

      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def calculate_platform_fee(price_cents, fee_split: "buyer")
      fee_percent = ENV.fetch("PLATFORM_FEE_PERCENT", 2.5).to_f
      min_fee = ENV.fetch("MIN_PLATFORM_FEE_CENTS", 500).to_i
      max_fee = ENV.fetch("MAX_PLATFORM_FEE_CENTS", 15_000).to_i

      fee = (price_cents * fee_percent / 100.0).round
      fee = [[fee, min_fee].max, max_fee].min

      case fee_split
      when "buyer"
        { buyer_fee: fee, seller_fee: 0, total_fee: fee }
      when "seller"
        { buyer_fee: 0, seller_fee: fee, total_fee: fee }
      when "split"
        half = (fee / 2.0).round
        { buyer_fee: half, seller_fee: fee - half, total_fee: fee }
      else
        { buyer_fee: fee, seller_fee: 0, total_fee: fee }
      end
    end

    # Return workflow methods
    def mark_return_shipped(trade, carrier:, tracking_number:)
      return { success: false, error: "Trade must be in rejected state" } unless trade.may_mark_return_shipped?
      return { success: false, error: "Tracking number is required" } if tracking_number.blank?

      shipment = trade.shipments.create!(
        account: trade.account,
        carrier: carrier.presence || "Unknown",
        tracking_number: tracking_number,
        direction: "return",
        status: "in_transit",
        shipped_at: Time.current
      )

      trade.mark_return_shipped!

      { success: true, shipment: shipment }
    rescue => e
      { success: false, error: e.message }
    end

    def mark_return_delivered(trade)
      return { success: false, error: "Invalid state" } unless trade.may_mark_return_delivered?

      trade.mark_return_delivered!
      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def confirm_return_receipt(trade)
      return { success: false, error: "Invalid state" } unless trade.may_confirm_return_receipt?

      trade.confirm_return_receipt!
      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def accept_return(trade)
      return { success: false, error: "Invalid state" } unless trade.may_accept_return?

      trade.accept_return!
      { success: true, message: "Return accepted. Refund will be processed." }
    rescue => e
      { success: false, error: e.message }
    end

    def reject_return(trade, rejection_reason: nil)
      return { success: false, error: "Invalid state" } unless trade.may_reject_return?

      trade.reject_return!

      # Create audit log with rejection reason if provided
      if rejection_reason.present?
        AuditLog.create!(
          trade: trade,
          account: trade.account,
          actor_id: trade.seller_id,
          action: "return_rejected",
          metadata: {
            rejection_reason: rejection_reason,
            timestamp: Time.current
          }
        )
      end

      { success: true, message: "Return rejected. Dispute opened." }
    rescue => e
      { success: false, error: e.message }
    end

    def calculate_payout_amount(trade)
      fees = calculate_platform_fee(trade.price_cents, fee_split: trade.fee_split)
      trade.price_cents - fees[:seller_fee]
    end

    # Signature workflow methods
    def send_for_signature(trade, deadline_hours: 168)
      return { success: false, error: "Trade cannot be sent for signature" } unless trade.may_send_for_signature?

      trade.signature_deadline_at = deadline_hours.hours.from_now
      trade.signature_sent_at = Time.current
      trade.send_for_signature!  # State transition with callbacks

      # The create_signature_document callback creates the TradeDocument
      # Get seller's signing URL immediately for return
      doc = trade.trade_documents.pending_status.last

      unless doc
        return { success: false, error: "Failed to create signature document" }
      end

      seller_sig = doc.document_signatures.seller_signer_role.first
      url_result = DocusealService.get_embedded_signing_url(seller_sig.docuseal_submitter_id)

      if url_result[:success]
        { success: true, trade: trade, signing_url: url_result[:url], slug: url_result[:slug] }
      else
        { success: false, error: url_result[:error] }
      end
    rescue => e
      Rails.logger.error "Error sending for signature: #{e.message}"
      { success: false, error: e.message }
    end

    def cancel_signature_request(trade)
      return { success: false, error: "Cannot cancel" } unless trade.may_cancel_signature_request?

      trade.cancel_signature_request!  # State transition handles cleanup
      { success: true, message: "Signature request cancelled" }
    rescue => e
      Rails.logger.error "Error cancelling signature: #{e.message}"
      { success: false, error: e.message }
    end

    def get_signing_url(trade, user)
      doc = trade.trade_documents.pending_status.last
      return { signed: false, error: "No pending document" } unless doc

      # Determine user's role
      role = (user.id == trade.seller_id) ? "seller" : "buyer"
      signature = doc.document_signatures.public_send("#{role}_signer_role").first

      return { signed: false, error: "Signature record not found" } unless signature
      return { signed: true, message: "You have already signed" } if signature.signed_at.present?

      result = DocusealService.get_embedded_signing_url(signature.docuseal_submitter_id)

      if result[:success]
        { signed: false, slug: result[:slug], url: result[:url] }
      else
        { signed: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "Error getting signing URL: #{e.message}"
      { signed: false, error: e.message }
    end

    # Create Stripe Checkout Session for escrow funding
    def create_checkout_session(trade, user)
      unless trade.awaiting_funding?
        return { success: false, error: "Trade must be awaiting funding" }
      end

      unless user.id == trade.buyer_id
        return { success: false, error: "Only the buyer can fund this trade" }
      end

      # Check if escrow already exists and has a pending payment
      if trade.escrow.present?
        case trade.escrow.status
        when 'held', 'funded'
          return { success: false, error: "Escrow has already been funded for this trade" }
        when 'pending'
          # Resume existing checkout session if still valid
          if trade.escrow.stripe_checkout_session_id.present?
            begin
              session = Stripe::Checkout::Session.retrieve(trade.escrow.stripe_checkout_session_id)
              if session.status == 'open'
                return { success: true, checkout_url: session.url }
              end
            rescue Stripe::StripeError => e
              Rails.logger.warn "Could not retrieve existing checkout session: #{e.message}"
            end
          end
        end
      end

      # Calculate total amount (price + platform fee if buyer pays)
      total_amount = trade.price_cents
      total_amount += trade.platform_fee_cents if trade.fee_split == 'buyer'

      begin
        # Create Stripe Checkout Session
        host = ENV.fetch("APP_HOST", "localhost:3000")
        success_url = Rails.application.routes.url_helpers.trade_url(trade, funding_success: true, host: host)
        cancel_url = Rails.application.routes.url_helpers.trade_url(trade, funding_cancelled: true, host: host)

        session = Stripe::Checkout::Session.create(
          mode: 'payment',
          success_url: success_url,
          cancel_url: cancel_url,
          customer_email: user.email,
          line_items: [
            {
              price_data: {
                currency: trade.currency.downcase,
                product_data: {
                  name: "Escrow Payment: #{trade.item&.name || 'Trade Item'}",
                  description: "Protected payment held in escrow until delivery confirmed"
                },
                unit_amount: total_amount
              },
              quantity: 1
            }
          ],
          payment_intent_data: {
            metadata: {
              trade_id: trade.id,
              buyer_id: user.id,
              seller_id: trade.seller_id,
              platform_fee_cents: trade.platform_fee_cents,
              fee_split: trade.fee_split
            },
            description: "Escrow for #{trade.item&.name || 'item'}",
            capture_method: 'automatic'
          },
          metadata: {
            trade_id: trade.id,
            buyer_id: user.id
          }
        )

        # Create or update escrow record
        escrow = trade.escrow || trade.build_escrow
        escrow.assign_attributes(
          account: trade.account,
          provider: 'stripe',
          amount_cents: total_amount,
          status: 'pending',
          stripe_checkout_session_id: session.id,
          payment_intent_id: session.payment_intent
        )

        if escrow.save
          Rails.logger.info "Checkout session created: #{session.id} for trade #{trade.id}"
          { success: true, checkout_url: session.url }
        else
          { success: false, error: escrow.errors.full_messages.join(", ") }
        end
      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe error creating checkout session: #{e.message}"
        { success: false, error: "Payment setup failed: #{e.message}" }
      end
    rescue => e
      Rails.logger.error "Error creating checkout session: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(15).join("\n")
      { success: false, error: "#{e.class}: #{e.message}" }
    end

    private

    def party?(trade, user)
      trade.buyer_id == user.id || trade.seller_id == user.id
    end

    def mark_agreed(trade, user)
      if trade.buyer_id == user.id && trade.buyer_agreed_at.nil?
        trade.update!(buyer_agreed_at: Time.current)
      elsif trade.seller_id == user.id && trade.seller_agreed_at.nil?
        trade.update!(seller_agreed_at: Time.current)
      end
    end

    def trade_url(trade, **params)
      Rails.application.routes.url_helpers.trade_url(trade, **params, host: ENV.fetch("APP_HOST", "localhost:3000"))
    end
  end
end
