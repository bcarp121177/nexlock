# frozen_string_literal: true

class TradeAgreementPdfGenerator
  HEADER_COLOR = "1F2937" # Gray-800 for professional look
  ACCENT_COLOR = "3B82F6" # Blue-500 for accents
  TEXT_COLOR = "111827"   # Gray-900 for body text
  LIGHT_GRAY = "F3F4F6"   # Gray-100 for backgrounds

  class << self
    def generate(trade)
      Prawn::Document.new(page_size: "LETTER", margin: 60) do |pdf|
        # Header Section
        add_header(pdf, trade)

        # Trade Summary Box
        add_trade_summary(pdf, trade)

        # Item Details
        add_item_details(pdf, trade)

        # Parties Information
        add_parties_info(pdf, trade)

        # Terms & Conditions
        add_terms_section(pdf, trade)

        # Signature Section with DocuSeal Text Tags
        add_signature_section(pdf, trade)

        # Footer
        add_footer(pdf, trade)
      end.render
    end

    private

    def add_header(pdf, trade)
      pdf.font "Helvetica", style: :bold, size: 24
      pdf.fill_color HEADER_COLOR
      pdf.text "TRADE AGREEMENT", align: :center
      pdf.move_down 5

      pdf.font "Helvetica", size: 12
      pdf.fill_color TEXT_COLOR
      pdf.text "Agreement ##{trade.id}", align: :center
      pdf.text "Created #{trade.created_at.strftime("%B %d, %Y")}", align: :center
      pdf.move_down 30
    end

    def add_trade_summary(pdf, trade)
      pdf.fill_color ACCENT_COLOR
      pdf.font "Helvetica", style: :bold, size: 14
      pdf.text "TRANSACTION SUMMARY"
      pdf.move_down 10

      pdf.fill_color TEXT_COLOR
      pdf.font "Helvetica", size: 11

      summary_data = [
        ["Item:", trade.item.name],
        ["Category:", trade.item.category.titleize],
        ["Condition:", trade.item.condition.titleize],
        ["Purchase Price:", format_currency(trade.price_cents)],
        ["Platform Fee:", format_currency(trade.platform_fee_cents)],
        ["Fee Paid By:", trade.fee_split.humanize],
        ["Inspection Window:", "#{trade.inspection_window_hours} hours"]
      ]

      summary_data.each do |label, value|
        pdf.text_box label, at: [0, pdf.cursor], width: 150, style: :bold
        pdf.text_box value, at: [150, pdf.cursor], width: 350
        pdf.move_down 18
      end

      pdf.move_down 10
    end

    def add_item_details(pdf, trade)
      pdf.fill_color ACCENT_COLOR
      pdf.font "Helvetica", style: :bold, size: 14
      pdf.text "ITEM DESCRIPTION"
      pdf.move_down 10

      pdf.fill_color TEXT_COLOR
      pdf.font "Helvetica", size: 10

      # Handle long descriptions - could span multiple pages
      description_text = trade.item.description || "No description provided"
      pdf.text description_text, leading: 3, align: :justify

      pdf.move_down 20
    end

    def add_parties_info(pdf, trade)
      pdf.fill_color ACCENT_COLOR
      pdf.font "Helvetica", style: :bold, size: 14
      pdf.text "PARTIES TO THIS AGREEMENT"
      pdf.move_down 10

      # Seller Information
      pdf.fill_color TEXT_COLOR
      pdf.font "Helvetica", style: :bold, size: 11
      pdf.text "SELLER"
      pdf.move_down 5
      pdf.font "Helvetica", size: 10
      pdf.text "Name: #{trade.seller_name || trade.seller.name}"
      pdf.text "Email: #{trade.seller.email}"
      if trade.seller_address_complete?
        pdf.text "Address:"
        pdf.indent(20) do
          pdf.text format_address(:seller, trade)
        end
      end
      pdf.move_down 15

      # Buyer Information - Collected via DocuSeal
      pdf.font "Helvetica", style: :bold, size: 11
      pdf.text "BUYER"
      pdf.move_down 5
      pdf.font "Helvetica", size: 9
      pdf.fill_color "999999"

      # DocuSeal will collect buyer information during signing
      pdf.text "Name: {{Buyer Name;role=Buyer;type=text;required=true}}"
      pdf.text "Email: #{trade.buyer_email}"
      pdf.text "Phone: {{Buyer Phone;role=Buyer;type=phone}}"
      pdf.move_down 5
      pdf.text "Shipping Address:"
      pdf.indent(20) do
        pdf.text "{{Buyer Street;role=Buyer;type=text;required=true}}"
        pdf.text "{{Buyer City;role=Buyer;type=text;required=true}}, {{Buyer State;role=Buyer;type=text;required=true}} {{Buyer ZIP;role=Buyer;type=text;required=true}}"
        pdf.text "{{Buyer Country;role=Buyer;type=text;required=true}}"
      end

      pdf.fill_color TEXT_COLOR
      pdf.move_down 20
    end

    def add_terms_section(pdf, trade)
      pdf.fill_color ACCENT_COLOR
      pdf.font "Helvetica", style: :bold, size: 14
      pdf.text "TERMS AND CONDITIONS"
      pdf.move_down 10

      pdf.fill_color TEXT_COLOR
      pdf.font "Helvetica", size: 10

      terms = [
        "1. The Seller agrees to ship the item described above to the Buyer within the agreed timeframe.",
        "2. The Buyer agrees to pay the purchase price of #{format_currency(trade.price_cents)} plus applicable fees.",
        "3. Payment will be held in escrow by Nexlock until the transaction is completed.",
        "4. The Buyer has #{trade.inspection_window_hours} hours from delivery to inspect the item and accept or reject it.",
        "5. If the item is accepted, funds will be released to the Seller.",
        "6. If the item is rejected, the Buyer must provide evidence and return the item for a refund.",
        "7. Return shipping costs will be paid by: #{trade.return_shipping_paid_by.humanize}.",
        "8. Both parties agree to Nexlock's Terms of Service and dispute resolution process.",
        "9. This agreement is binding upon execution by both parties via digital signature."
      ]

      terms.each do |term|
        pdf.text term, leading: 4
        pdf.move_down 8
      end

      pdf.move_down 10
    end

    def add_signature_section(pdf, trade)
      # Start new page if not enough space
      if pdf.cursor < 250
        pdf.start_new_page
      end

      pdf.fill_color ACCENT_COLOR
      pdf.font "Helvetica", style: :bold, size: 14
      pdf.text "SIGNATURES"
      pdf.move_down 10

      pdf.fill_color TEXT_COLOR
      pdf.font "Helvetica", size: 10
      pdf.text "By signing below, both parties agree to the terms and conditions outlined in this agreement."
      pdf.move_down 20

      # Seller Signature Area with DocuSeal Text Tags
      pdf.font "Helvetica", style: :bold, size: 11
      pdf.text "SELLER SIGNATURE"
      pdf.move_down 5

      pdf.font "Helvetica", size: 9
      pdf.fill_color "999999"
      # DocuSeal text tag - will be replaced with signature field
      pdf.text "{{Seller Signature;role=Seller;type=signature}}"
      pdf.move_down 5
      pdf.text "Date: {{Seller Date;role=Seller;type=date}}"
      pdf.move_down 5
      pdf.text "Name: #{trade.seller_name || trade.seller.name}"
      pdf.move_down 30

      # Buyer Signature Area with DocuSeal Text Tags
      pdf.fill_color TEXT_COLOR
      pdf.font "Helvetica", style: :bold, size: 11
      pdf.text "BUYER SIGNATURE"
      pdf.move_down 5

      pdf.font "Helvetica", size: 9
      pdf.fill_color "999999"
      # DocuSeal text tag - will be replaced with signature field
      pdf.text "{{Buyer Signature;role=Buyer;type=signature}}"
      pdf.move_down 5
      pdf.text "Date: {{Buyer Date;role=Buyer;type=date}}"
      pdf.move_down 5
      pdf.text "Name: {{Buyer Name;role=Buyer;type=text;readonly=true}}"
    end

    def add_footer(pdf, trade)
      pdf.number_pages "Page <page> of <total>",
                       at: [pdf.bounds.right - 150, 0],
                       align: :right,
                       size: 9

      pdf.repeat(:all) do
        pdf.bounding_box([0, 20], width: pdf.bounds.width, height: 20) do
          pdf.font "Helvetica", size: 8
          pdf.fill_color "666666"
          pdf.text "Nexlock Trade Agreement ##{trade.id} | This is a legally binding contract", align: :center
        end
      end
    end

    def format_currency(cents)
      "$#{"%.2f" % (cents / 100.0)}"
    end

    def format_address(party, trade)
      prefix = party.to_s
      parts = [
        trade.public_send("#{prefix}_street1"),
        trade.public_send("#{prefix}_street2"),
        "#{trade.public_send("#{prefix}_city")}, #{trade.public_send("#{prefix}_state")} #{trade.public_send("#{prefix}_zip")}",
        trade.public_send("#{prefix}_country")
      ].compact.reject(&:blank?)

      parts.join("\n")
    end
  end
end
