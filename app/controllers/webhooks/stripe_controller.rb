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
  end
end
