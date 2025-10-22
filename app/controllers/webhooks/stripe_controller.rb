module Webhooks
  class StripeController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :verify_authenticity_token

    def create
      event = construct_event
      return head :bad_request unless event

      case event.type
      when "account.updated"
        handle_account_updated(event.data.object)
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "payment_intent.succeeded"
        handle_payment_succeeded(event.data.object)
      when "charge.succeeded"
        handle_charge_succeeded(event.data.object)
      else
        Rails.logger.info "Stripe webhook received unhandled event: #{event.type}"
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Stripe webhook payload error: #{e.message}"
      head :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Stripe webhook signature error: #{e.message}"
      head :bad_request
    rescue => e
      Rails.logger.error "Stripe webhook processing error: #{e.message}"
      head :internal_server_error
    end

    private

    def construct_event
      payload = request.body.read
      signature = request.env["HTTP_STRIPE_SIGNATURE"]
      secret = Rails.application.config.x.stripe&.webhook_secret || ENV["STRIPE_WEBHOOK_SECRET"].presence

      unless secret
        Rails.logger.warn "Stripe webhook secret is not configured"
        return nil
      end

      Stripe::Webhook.construct_event(payload, signature, secret)
    end

    def handle_account_updated(account)
      user = User.find_by(stripe_connect_id: account.id)

      unless user
        Rails.logger.warn "Stripe webhook account.updated with unknown account #{account.id}"
        return
      end

      new_status = if account.payouts_enabled && account.charges_enabled
        "verified"
      elsif Array(account.requirements.currently_due).any? || Array(account.requirements.past_due).any?
        "pending"
      else
        user.kyc_status
      end

      return if new_status == user.kyc_status

      user.update!(kyc_status: new_status)
      Rails.logger.info "Updated user ##{user.id} KYC status to #{new_status} via Stripe webhook"
    end

    def handle_checkout_completed(session)
      trade_id = session.metadata.trade_id
      unless trade_id
        Rails.logger.error "No trade_id in checkout session metadata"
        return
      end

      trade = Trade.find_by(id: trade_id)
      unless trade
        Rails.logger.error "Trade not found: #{trade_id}"
        return
      end

      escrow = trade.escrow
      unless escrow
        Rails.logger.error "No escrow record for trade #{trade_id}"
        return
      end

      # Update escrow with payment_intent_id from completed session
      if session.payment_intent.present?
        escrow.update(payment_intent_id: session.payment_intent)
      end

      Rails.logger.info "Checkout completed for trade #{trade_id}, waiting for payment_intent.succeeded"
    end

    def handle_payment_succeeded(payment_intent)
      trade_id = payment_intent.metadata.trade_id
      unless trade_id
        Rails.logger.error "No trade_id in payment_intent metadata"
        return
      end

      trade = Trade.find_by(id: trade_id)
      unless trade
        Rails.logger.error "Trade not found: #{trade_id}"
        return
      end

      escrow = trade.escrow
      unless escrow
        Rails.logger.error "No escrow record for trade #{trade_id}"
        return
      end

      # Update escrow status to held
      escrow.update!(
        status: 'held',
        payment_method_id: payment_intent.payment_method,
        funded_at: Time.current
      )

      # Transition trade to funded state
      if trade.may_mark_funded?
        trade.mark_funded!

        AuditLog.create!(
          trade: trade,
          account: trade.account,
          actor_id: trade.buyer_id,
          action: "payment_succeeded",
          metadata: {
            payment_intent_id: payment_intent.id,
            amount_cents: payment_intent.amount,
            timestamp: Time.current
          }
        )

        Rails.logger.info "Trade #{trade.id} funded successfully via Stripe webhook"
      else
        Rails.logger.error "Trade #{trade.id} cannot transition to funded from #{trade.state}"
      end
    rescue => e
      Rails.logger.error "Error handling payment succeeded: #{e.message}\n#{e.backtrace.join("\n")}"
    end

    def handle_charge_succeeded(charge)
      trade_id = charge.metadata.trade_id
      unless trade_id
        Rails.logger.error "No trade_id in charge metadata"
        return
      end

      trade = Trade.find_by(id: trade_id)
      unless trade
        Rails.logger.error "Trade not found: #{trade_id}"
        return
      end

      escrow = trade.escrow
      unless escrow
        Rails.logger.error "No escrow record for trade #{trade_id}"
        return
      end

      # Update escrow status to held
      escrow.update!(
        status: 'held',
        payment_method_id: charge.payment_method,
        funded_at: Time.current
      )

      # Transition trade to funded state
      if trade.may_mark_funded?
        trade.mark_funded!

        AuditLog.create!(
          trade: trade,
          account: trade.account,
          actor_id: trade.buyer_id,
          action: "payment_succeeded",
          metadata: {
            charge_id: charge.id,
            amount_cents: charge.amount,
            timestamp: Time.current
          }
        )

        Rails.logger.info "Trade #{trade.id} funded successfully via charge.succeeded webhook"
      else
        Rails.logger.error "Trade #{trade.id} cannot transition to funded from #{trade.state}"
      end
    rescue => e
      Rails.logger.error "Error handling charge succeeded: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end
