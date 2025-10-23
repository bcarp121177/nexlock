# frozen_string_literal: true

class DocusealService
  class << self
    # Create a submission from template with merged trade data
    def create_submission(trade:)
      config = Rails.application.config.x.docuseal
      return { success: false, error: "DocuSeal API key not configured" } unless config.api_key
      return { success: false, error: "DocuSeal template ID not configured" } unless config.trade_agreement_template_id

      submitters_data = build_submitters(trade)

      Rails.logger.info "=" * 80
      Rails.logger.info "DocuSeal Submission Data for Trade ##{trade.id}"
      Rails.logger.info "=" * 80
      Rails.logger.info "Template ID: #{config.trade_agreement_template_id}"
      Rails.logger.info "Submitters:"
      submitters_data.each_with_index do |submitter, index|
        Rails.logger.info "  #{index + 1}. #{submitter[:role]} (#{submitter[:email]})"
        Rails.logger.info "     Fields being sent:"
        submitter[:values].each do |key, value|
          Rails.logger.info "       - #{key}: #{value}"
        end
      end
      Rails.logger.info "=" * 80

      response = connection.post("/submissions") do |req|
        req.body = {
          template_id: config.trade_agreement_template_id,
          send_email: false,  # We handle emails ourselves
          order: "preserved",  # Sequential signing: Seller → Buyer
          submitters: submitters_data
        }
      end

      parse_response(response)
    rescue Faraday::Error => e
      Rails.logger.error "DocuSeal API error: #{e.message}"
      { success: false, error: e.message }
    rescue => e
      Rails.logger.error "Unexpected error in create_submission: #{e.message}"
      { success: false, error: e.message }
    end

    # Get embedded signing URL for a specific submitter
    def get_embedded_signing_url(submitter_id)
      config = Rails.application.config.x.docuseal
      return { success: false, error: "DocuSeal API key not configured" } unless config.api_key

      response = connection.get("/submitters/#{submitter_id}")
      data = parse_response(response)

      if data[:success]
        Rails.logger.info "DocuSeal submitter response: #{data[:data].inspect}"
        { success: true, url: data[:data]["embed_url"], slug: data[:data]["slug"] }
      else
        data
      end
    rescue => e
      Rails.logger.error "Error getting signing URL: #{e.message}"
      { success: false, error: e.message }
    end

    # Get submission status
    def get_submission_status(submission_id)
      config = Rails.application.config.x.docuseal
      return { success: false, error: "DocuSeal API key not configured" } unless config.api_key

      response = connection.get("/submissions/#{submission_id}")
      parse_response(response)
    rescue => e
      Rails.logger.error "Error getting submission status: #{e.message}"
      { success: false, error: e.message }
    end

    # Download signed PDF
    def download_signed_document(submission_id)
      config = Rails.application.config.x.docuseal
      return { success: false, error: "DocuSeal API key not configured" } unless config.api_key

      response = connection.get("/submissions/#{submission_id}/download")

      if response.success?
        { success: true, pdf_data: response.body }
      else
        { success: false, error: "Download failed: #{response.status}" }
      end
    rescue => e
      Rails.logger.error "Error downloading document: #{e.message}"
      { success: false, error: e.message }
    end

    # Cancel/void submission
    def cancel_submission(submission_id)
      config = Rails.application.config.x.docuseal
      return { success: false, error: "DocuSeal API key not configured" } unless config.api_key

      response = connection.delete do |req|
        req.url "/submissions/#{submission_id}"
      end
      parse_response(response)
    rescue => e
      Rails.logger.error "Error cancelling submission: #{e.message}"
      { success: false, error: e.message }
    end

    # Get template details including fields
    def get_template(template_id = nil)
      config = Rails.application.config.x.docuseal
      return { success: false, error: "DocuSeal API key not configured" } unless config.api_key

      template_id ||= config.trade_agreement_template_id
      response = connection.get("/templates/#{template_id}")
      parse_response(response)
    rescue => e
      Rails.logger.error "Error getting template: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def connection
      config = Rails.application.config.x.docuseal

      @connection ||= Faraday.new(url: config.api_url) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.headers["X-Auth-Token"] = config.api_key
        f.adapter Faraday.default_adapter
      end
    end

    def build_submitters(trade)
      # Build common merge fields
      common_fields = merge_fields_for_trade(trade)

      [
        {
          role: "Seller",
          email: trade.seller.email,
          name: trade.seller_name || trade.seller.name,
          values: common_fields.merge({
            seller_name_confirm: trade.seller_name || trade.seller.name,
            seller_email_confirm: trade.seller.email,
            seller_date: Time.current.strftime("%B %d, %Y")
          })
        },
        {
          role: "Buyer",
          email: trade.buyer_email,
          name: trade.buyer_name || trade.buyer_email.split("@").first.titleize,
          values: common_fields.merge({
            buyer_name_confirm: trade.buyer_name || trade.buyer_email.split("@").first.titleize,
            buyer_email_confirm: trade.buyer_email,
            buyer_date: Time.current.strftime("%B %d, %Y")
          })
        }
      ]
    end

    def merge_fields_for_trade(trade)
      {
        seller_name: trade.seller_name || trade.seller.name,
        seller_email: trade.seller.email,
        seller_address: format_address(:seller, trade),
        seller_city: trade.seller_city || "",
        seller_state: trade.seller_state || "",
        seller_zip: trade.seller_zip || "",
        buyer_name: trade.buyer_name || trade.buyer_email.split("@").first.titleize,
        buyer_email: trade.buyer_email,
        buyer_address: format_address(:buyer, trade),
        buyer_city: trade.buyer_city || "",
        buyer_state: trade.buyer_state || "",
        buyer_zip: trade.buyer_zip || "",
        item_name: trade.item.name,
        item_description: trade.item.description,
        item_category: trade.item.category.titleize,
        item_condition: trade.item.condition.titleize,
        price: format_currency(trade.price_cents),
        currency: trade.currency,
        inspection_window: "#{trade.inspection_window_hours} hours",
        platform_fee: format_currency(trade.platform_fee_cents),
        fee_split: trade.fee_split.humanize,
        trade_id: trade.id,
        created_date: trade.created_at.strftime("%B %d, %Y")
      }
    end

    def format_address(party, trade)
      prefix = party.to_s
      street1 = trade.public_send("#{prefix}_street1")
      street2 = trade.public_send("#{prefix}_street2")
      city = trade.public_send("#{prefix}_city")
      state = trade.public_send("#{prefix}_state")
      zip = trade.public_send("#{prefix}_zip")
      country = trade.public_send("#{prefix}_country")

      # Return placeholder if no address provided
      return "Address not provided" if [street1, city, state, zip].all?(&:blank?)

      parts = [
        street1,
        street2,
        [city, state, zip].compact.join(", "),
        country
      ].compact.reject(&:blank?)

      parts.join("\n")
    end

    def format_currency(cents)
      "$#{"%.2f" % (cents / 100.0)}"
    end

    def parse_response(response)
      if response.success?
        { success: true, data: response.body }
      else
        error_message = response.body.is_a?(Hash) ? response.body["error"] : "Unknown error"
        { success: false, error: error_message || "HTTP #{response.status}" }
      end
    end
  end
end
