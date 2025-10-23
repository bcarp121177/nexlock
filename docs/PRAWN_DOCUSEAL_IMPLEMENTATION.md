Analysis

  Current State:
  - DocuSealService creates submissions from a pre-built template (template_id: 1891351)
  - Field values are merged into template fields
  - Template has fixed layout → content overflow issues
  - TradeDocumentService orchestrates the document lifecycle

  New Approach:
  - Generate PDF dynamically with Prawn (flexible layout, handles variable content)
  - Upload generated PDF to DocuSeal
  - Programmatically add signature fields at specific coordinates
  - Use DocuSeal solely for signature workflow, not layout

  Implementation Plan

  Phase 1: PDF Generation Service

  Create app/services/trade_agreement_pdf_generator.rb
  - Use Prawn to generate a complete trade agreement PDF
  - Include all trade details with proper formatting
  - Handle variable-length text (descriptions, addresses)
  - Add signature placeholders (we'll position DocuSeal signatures over these)
  - Return PDF as binary data

  Key decisions:
  - Multi-page support for long descriptions
  - Consistent styling (fonts, colors, spacing)
  - Include headers/footers with trade ID
  - Terms & conditions section

  Phase 2: Update DocuSeal Service

  Add new methods to app/services/docuseal_service.rb:
  1. upload_document(pdf_data, filename) - Upload generated PDF
  2. create_submission_from_document(document_id, trade) - Create submission from uploaded doc
  3. add_signature_fields(document_id, fields) - Define signature field positions

  DocuSeal API endpoints to use:
  - POST /documents - Upload PDF
  - POST /templates - Create template from document (or)
  - POST /submissions with document instead of template_id

  Phase 3: Update Trade Document Service

  Modify TradeDocumentService.create_trade_agreement:
  1. Generate PDF using TradeAgreementPdfGenerator
  2. Upload PDF to DocuSeal → get document_id
  3. Create submission with signature fields
  4. Create TradeDocument record (same as before)
  5. Create DocumentSignature records (same as before)

  Phase 4: Signature Field Positioning

  Challenge: Need exact pixel coordinates for signatures

  Options:
  1. Fixed positions: Put signature areas at bottom of page 1, page 2
  2. Prawn markers: Add invisible markers in PDF, detect positions programmatically
  3. Manual calibration: Generate sample PDF, measure coordinates, hardcode

  Recommendation: Option 1 (simplest) - reserve fixed areas for signatures

  Phase 5: Testing & Migration

  - Test with various content lengths
  - Verify signature workflow still works
  - Test email notifications still trigger
  - Consider: migrate existing trades or leave them on old system?

  Key Questions Before Implementation

  1. DocuSeal API capabilities: Does their API support uploading custom PDFs and adding signature fields programmatically? (Need to verify API docs)
  2. Coordinate system: How does DocuSeal handle signature field positioning? (pixels, percentages, PDF units?)
  3. Migration: Do we migrate existing in-progress trades or just use new system for new trades?
  4. PDF storage: Should we store the generated PDF before sending to DocuSeal? (for audit trail)
  5. Template reuse: Can we create a "dynamic template" from the first generated PDF and reuse it, or generate fresh each time?

  Recommended Next Steps

  1. Research DocuSeal API - Verify they support document upload + programmatic field placement
  2. Create proof-of-concept - Generate simple PDF with Prawn, upload to DocuSeal manually
  3. Test signature positioning - Understand DocuSeal's coordinate system
  4. Full implementation - Build the services
  5. Incremental rollout - New trades use new system, old trades continue with template



  DocuSeal provides two methods for uploading custom PDFs and adding signature fields:

  ---
  Method 1: Text Tags (RECOMMENDED)

  How it works:
  - Add text tags directly in your PDF using Prawn
  - Format: {{Field Name;role=RoleName;type=fieldtype}}
  - DocuSeal automatically detects and converts tags to interactive fields

  Advantages:
  - ✅ No coordinate calculations needed
  - ✅ Tags positioned exactly where you place them in Prawn
  - ✅ Easier to maintain
  - ✅ Auto-adjusts to content flow

  Example tags for our use case:
  {{Seller Signature;role=Seller;type=signature}}
  {{Seller Date;role=Seller;type=date}}
  {{Buyer Signature;role=Buyer;type=signature}}
  {{Buyer Date;role=Buyer;type=date}}

  API Endpoint: POST /submissions/pdf
  {
    name: "Trade Agreement ##{trade.id}",
    documents: [{
      file: Base64.encode64(pdf_data)
    }],
    submitters: [
      { role: "Seller", email: trade.seller.email },
      { role: "Buyer", email: trade.buyer_email }
    ],
    send_email: false,
    order: "preserved"
  }

  ---
  Method 2: Pixel Coordinates

  How it works:
  - Upload plain PDF
  - Specify exact x,y,w,h coordinates for each field
  - More control but requires measurement

  Advantages:
  - ✅ Precise positioning
  - ✅ Works with existing PDFs

  Disadvantages:
  - ❌ Need to calculate coordinates
  - ❌ Brittle if layout changes
  - ❌ More complex code

  ---
  Recommended Implementation Plan

  Phase 1: PDF Generator with Text Tags

  File: app/services/trade_agreement_pdf_generator.rb

  class TradeAgreementPdfGenerator
    def self.generate(trade)
      Prawn::Document.new do |pdf|
        # Header
        pdf.text "TRADE AGREEMENT", size: 20, style: :bold, align: :center
        pdf.text "Trade ##{trade.id}", size: 12, align: :center
        pdf.move_down 20

        # Trade Details
        pdf.text "Item: #{trade.item.name}", size: 14, style: :bold
        pdf.text "Description: #{trade.item.description}"
        pdf.text "Price: #{format_currency(trade.price_cents)}"
        pdf.move_down 15

        # Parties
        pdf.text "Seller: #{trade.seller_name || trade.seller.name}"
        pdf.text "Buyer: #{trade.buyer_name || trade.buyer_email}"
        pdf.move_down 15

        # Terms
        pdf.text "Terms & Conditions", size: 14, style: :bold
        pdf.text "Inspection Window: #{trade.inspection_window_hours} hours"
        pdf.text "Fees: #{format_currency(trade.platform_fee_cents)} (#{trade.fee_split})"
        pdf.move_down 30

        # Signature areas with TEXT TAGS
        pdf.text "Seller Signature:"
        pdf.text "{{Seller Signature;role=Seller;type=signature}}", size: 10, color: "CCCCCC"
        pdf.text "Date: {{Seller Date;role=Seller;type=date}}", size: 10, color: "CCCCCC"
        pdf.move_down 30

        pdf.text "Buyer Signature:"
        pdf.text "{{Buyer Signature;role=Buyer;type=signature}}", size: 10, color: "CCCCCC"
        pdf.text "Date: {{Buyer Date;role=Buyer;type=date}}", size: 10, color: "CCCCCC"
      end.render
    end
  end

  Phase 2: Update DocuSeal Service

  Add to: app/services/docuseal_service.rb

  # Create submission from PDF with embedded text tags
  def create_submission_from_pdf(trade:, pdf_data:)
    config = Rails.application.config.x.docuseal

    response = connection.post("/submissions/pdf") do |req|
      req.body = {
        name: "Trade Agreement ##{trade.id}",
        documents: [{
          name: "trade_agreement_#{trade.id}.pdf",
          file: Base64.strict_encode64(pdf_data)
        }],
        submitters: [
          {
            role: "Seller",
            email: trade.seller.email,
            name: trade.seller_name || trade.seller.name
          },
          {
            role: "Buyer",
            email: trade.buyer_email,
            name: trade.buyer_name || "Buyer"
          }
        ],
        send_email: false,
        order: "preserved"
      }
    end

    parse_response(response)
  end

  Phase 3: Update Trade Document Service

  Modify: app/services/trade_document_service.rb

  def create_trade_agreement(trade)
    # Generate PDF with trade data
    pdf_data = TradeAgreementPdfGenerator.generate(trade)

    # Create submission in DocuSeal (text tags auto-detected)
    result = DocusealService.create_submission_from_pdf(
      trade: trade,
      pdf_data: pdf_data
    )

    return result unless result[:success]

    # Rest of existing logic (create trade_document, signatures, etc.)
    # ... same as current implementation
  end

  ---
  Key Benefits of This Approach

  1. ✅ No coordinate calculations - Tags go exactly where you place them
  2. ✅ Dynamic layout - Prawn handles wrapping, pagination automatically
  3. ✅ Easy maintenance - Change PDF layout without touching coordinates
  4. ✅ Same signing workflow - Rest of app unchanged
  5. ✅ Audit trail - Can store generated PDF before sending to DocuSeal
  6. ✅ Professional appearance - Full control over styling, fonts, layout