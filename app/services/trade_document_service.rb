# frozen_string_literal: true

class TradeDocumentService
  class << self
    # Create trade agreement document and initiate DocuSeal submission
    def create_trade_agreement(trade)
      # Generate PDF with Prawn
      Rails.logger.info "Generating trade agreement PDF for Trade ##{trade.id}"
      pdf_data = TradeAgreementPdfGenerator.generate(trade)

      # Create submission in DocuSeal with generated PDF
      result = DocusealService.create_submission_from_pdf(trade: trade, pdf_data: pdf_data)

      return result unless result[:success]

      submission_data = result[:data]

      # Extract submission ID and submitters from response
      # Response format: { "id": 123, "submitters": [...], ... }
      submission_id = submission_data["id"]
      submitters = submission_data["submitters"]

      Rails.logger.info "DocuSeal submission created: ID #{submission_id}"
      Rails.logger.info "Submitters: #{submitters.map { |s| "#{s['role']} (#{s['email']})" }.join(", ")}"

      # Create trade_documents record
      trade_document = trade.trade_documents.create!(
        account: trade.account,
        document_type: :trade_agreement,
        title: "Trade Agreement ##{trade.id}",
        docuseal_submission_id: submission_id.to_s,
        docuseal_template_id: nil, # No longer using templates
        status: :pending,
        docuseal_document_url: nil, # We'll set this later when completed
        expires_at: trade.signature_deadline_at
      )

      # Create document_signatures records for tracking
      submitters.each do |submitter|
        signer_role = submitter["role"].downcase.to_sym
        signer_email = submitter["email"]

        trade_document.document_signatures.create!(
          account: trade.account,
          user: find_user_by_email(signer_email),
          signer_email: signer_email,
          signer_role: signer_role,
          docuseal_submitter_id: submitter["id"].to_s,
          docuseal_slug: submitter["slug"]
        )
      end

      Rails.logger.info "Trade #{trade.id} signature document created successfully"

      { success: true, trade_document: trade_document }
    rescue => e
      Rails.logger.error "Failed to create trade agreement: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, error: e.message }
    end

    # Process signature completion from webhook
    def process_signature_completion(trade_document, submitter_id, webhook_data = {})
      Rails.logger.info "Looking for signature with submitter_id: #{submitter_id.inspect}"
      Rails.logger.info "Available signatures: #{trade_document.document_signatures.pluck(:id, :docuseal_submitter_id).inspect}"

      signature = trade_document.document_signatures.find_by(
        docuseal_submitter_id: submitter_id.to_s
      )

      Rails.logger.info "Found signature: #{signature.inspect}"

      unless signature
        Rails.logger.error "Signature not found for submitter_id: #{submitter_id}"
        return { success: false, error: "Signature not found" }
      end

      # Update signature record
      signature.update!(
        signed_at: Time.current,
        ip_address: webhook_data["ip"] || webhook_data[:ip],
        user_agent: webhook_data["ua"] || webhook_data[:ua],
        signature_metadata: webhook_data
      )

      Rails.logger.info "Signature #{signature.id} recorded for #{signature.signer_role}"

      # Update trade timestamps and trigger state transitions
      trade = trade_document.trade
      if signature.seller_signer_role?
        if trade.may_seller_signs?
          trade.seller_signs!
          Rails.logger.info "Trade #{trade.id} - Seller signed"
        end
      elsif signature.buyer_signer_role?
        if trade.may_buyer_signs?
          trade.buyer_signs!
          Rails.logger.info "Trade #{trade.id} - Buyer signed"

          # Both signed - finalize document
          finalize_trade_document(trade_document)
        end
      end

      { success: true, signature: signature }
    rescue => e
      Rails.logger.error "Failed to process signature: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, error: e.message }
    end

    # Finalize document after all signatures collected
    def finalize_trade_document(trade_document)
      Rails.logger.info "Finalizing trade document #{trade_document.id}"

      # Download signed PDF from DocuSeal
      result = DocusealService.download_signed_document(
        trade_document.docuseal_submission_id
      )

      return result unless result[:success]

      # Attach PDF to trade using Active Storage
      trade = trade_document.trade
      filename = "trade_agreement_#{trade.id}.pdf"

      trade.signed_agreement.attach(
        io: StringIO.new(result[:pdf_data]),
        filename: filename,
        content_type: "application/pdf"
      )

      # Update trade_document with final URL
      signed_url = trade.signed_agreement.url

      trade_document.update!(
        status: :completed,
        signed_document_url: signed_url,
        completed_at: Time.current
      )

      Rails.logger.info "Trade #{trade.id} document finalized - PDF stored"

      { success: true, trade_document: trade_document }
    rescue => e
      Rails.logger.error "Failed to finalize document: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, error: e.message }
    end

    # Check for expired signature deadlines (called by background job)
    def check_signature_deadlines
      # Check for expired deadlines
      expired_trades = Trade.where(
        state: [:awaiting_seller_signature, :awaiting_buyer_signature]
      ).where("signature_deadline_at <= ?", Time.current)

      expired_count = 0
      expired_trades.find_each do |trade|
        if trade.may_signature_deadline_expired?
          trade.signature_deadline_expired!
          Rails.logger.info "Trade #{trade.id} signature deadline expired"
          expired_count += 1
        end
      end

      # Send reminders for deadlines expiring within 24 hours
      reminder_deadline = 24.hours.from_now
      upcoming_trades = Trade.where(
        state: [:awaiting_seller_signature, :awaiting_buyer_signature]
      ).where("signature_deadline_at > ? AND signature_deadline_at <= ?", Time.current, reminder_deadline)

      reminder_count = 0
      upcoming_trades.find_each do |trade|
        # Check if we've already sent a reminder (using a flag or checking created_at)
        # For now, we'll send it every time the job runs (which should be daily)
        trade.notify_signature_deadline_reminder
        Rails.logger.info "Sent signature deadline reminder for trade #{trade.id}"
        reminder_count += 1
      end

      { expired_count: expired_count, reminder_count: reminder_count }
    end

    private

    def find_user_by_email(email)
      User.find_by(email: email.downcase.strip)
    end
  end
end
