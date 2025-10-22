class Webhooks::DocusealController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_webhook_signature

  def create
    event_type = params[:event_type]

    Rails.logger.info "DocuSeal webhook received: #{event_type}"

    case event_type
    when "submitter.signed", "form.completed"
      handle_signature_completion
    when "submission.completed"
      handle_submission_completed
    when "submission.expired", "form.expired"
      handle_submission_expired
    else
      Rails.logger.info "Unhandled DocuSeal webhook event: #{event_type}"
    end

    head :ok
  rescue => e
    Rails.logger.error "DocuSeal webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :unprocessable_entity
  end

  private

  def handle_signature_completion
    submission_id = params.dig(:data, :submission_id).to_s
    submitter_id = params.dig(:data, :id).to_s

    Rails.logger.info "Processing signature - submission_id: #{submission_id}, submitter_id: #{submitter_id}"

    trade_document = TradeDocument.find_by(docuseal_submission_id: submission_id)

    unless trade_document
      Rails.logger.error "TradeDocument not found for submission_id: #{submission_id}"
      return
    end

    Rails.logger.info "Found TradeDocument #{trade_document.id} for Trade #{trade_document.trade_id}"

    result = TradeDocumentService.process_signature_completion(trade_document, submitter_id, params[:data])

    unless result[:success]
      Rails.logger.error "Failed to process signature: #{result[:error]}"
    end
  end

  def handle_submission_completed
    # Similar to signature completion - ensures document is finalized
    handle_signature_completion
  end

  def handle_submission_expired
    submission_id = params.dig(:data, :id).to_s
    trade_document = TradeDocument.find_by(docuseal_submission_id: submission_id)

    if trade_document && trade_document.trade.may_signature_deadline_expired?
      trade_document.trade.signature_deadline_expired!
      Rails.logger.info "Trade #{trade_document.trade.id} signature expired via webhook"
    end
  end

  def verify_webhook_signature
    webhook_secret = Rails.application.config.x.docuseal.webhook_secret

    # Allow in development without secret or with placeholder
    if Rails.env.development? && (webhook_secret.blank? || webhook_secret == "my_docuseal_secret")
      Rails.logger.warn "DocuSeal webhook verification skipped in development"
      return true
    end

    provided_signature = request.headers["X-Docuseal-Signature"]

    if webhook_secret.blank?
      Rails.logger.warn "DocuSeal webhook secret not configured"
      return true if Rails.env.development?
      head :unauthorized
      return false
    end

    expected_signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      webhook_secret,
      request.raw_post
    )

    unless ActiveSupport::SecurityUtils.secure_compare(
      provided_signature.to_s,
      expected_signature
    )
      Rails.logger.error "DocuSeal webhook signature verification failed"
      Rails.logger.error "Provided: #{provided_signature}"
      Rails.logger.error "Expected: #{expected_signature}"
      head :unauthorized
      return false
    end

    true
  end
end
