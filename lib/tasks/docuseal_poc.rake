# frozen_string_literal: true

namespace :docuseal do
  desc "Generate sample PDF with DocuSeal text tags for POC testing"
  task generate_sample_pdf: :environment do
    puts "=" * 80
    puts "DocuSeal POC: Generating sample PDF with text tags"
    puts "=" * 80

    # Find or create a sample trade
    trade = Trade.includes(:item, :seller).first

    unless trade
      puts "❌ No trades found in database. Creating a sample trade..."

      # Create sample data
      account = Account.first || Account.create!(
        name: "Sample Account",
        owner: User.first || User.create!(
          email: "seller@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "John",
          last_name: "Seller",
          terms_of_service: true
        )
      )

      trade = Trade.create!(
        account: account,
        seller: account.owner,
        buyer_email: "buyer@example.com",
        buyer_name: "Jane Buyer",
        price_cents: 150_000, # $1,500
        platform_fee_cents: 7_500, # $75
        fee_split: "split",
        inspection_window_hours: 48,
        return_shipping_paid_by: "seller",
        seller_name: "John Seller",
        seller_email: "seller@example.com",
        seller_street1: "123 Main St",
        seller_city: "Austin",
        seller_state: "TX",
        seller_zip: "78701",
        seller_country: "United States",
        buyer_street1: "456 Oak Ave",
        buyer_city: "Portland",
        buyer_state: "OR",
        buyer_zip: "97201",
        buyer_country: "United States"
      )

      trade.create_item!(
        account: account,
        name: "Fender Stratocaster Electric Guitar",
        description: "Beautiful 2019 Fender American Professional Stratocaster in Olympic White. " \
                     "This guitar is in excellent condition with minimal wear. " \
                     "Features include alder body, maple neck with rosewood fingerboard, " \
                     "V-Mod single-coil pickups, and upgraded bone nut. " \
                     "Includes original hard shell case, all documentation, and case candy. " \
                     "Plays beautifully with low action and great tone across all pickup positions. " \
                     "No structural issues, just a few minor cosmetic marks from normal use. " \
                     "Perfect for professional players or serious collectors.",
        category: "guitar",
        condition: "excellent",
        price_cents: 150_000
      )
    end

    puts "\n📄 Generating PDF for Trade ##{trade.id}..."
    puts "   Item: #{trade.item.name}"
    puts "   Price: #{ActionController::Base.helpers.number_to_currency(trade.price_cents / 100.0)}"

    # Generate PDF
    pdf_data = TradeAgreementPdfGenerator.generate(trade)

    # Save to tmp directory
    output_path = Rails.root.join("tmp", "trade_agreement_#{trade.id}_sample.pdf")
    File.binwrite(output_path, pdf_data)

    puts "\n✅ PDF generated successfully!"
    puts "   Location: #{output_path}"
    puts "   Size: #{(pdf_data.bytesize / 1024.0).round(2)} KB"
    puts "\n📋 DocuSeal Text Tags Included:"
    puts "   - {{Seller Signature;role=Seller;type=signature}}"
    puts "   - {{Seller Date;role=Seller;type=date}}"
    puts "   - {{Buyer Signature;role=Buyer;type=signature}}"
    puts "   - {{Buyer Date;role=Buyer;type=date}}"
    puts "\n🧪 Next Steps:"
    puts "   1. Open the PDF: open #{output_path}"
    puts "   2. Review the layout and styling"
    puts "   3. Test with DocuSeal API to verify text tag detection"
    puts "=" * 80
  end

  desc "Test DocuSeal submission with generated PDF"
  task test_submission: :environment do
    puts "=" * 80
    puts "DocuSeal POC: Testing PDF upload with text tags"
    puts "=" * 80

    trade = Trade.includes(:item, :seller).first
    unless trade
      puts "❌ No trades found. Run 'rake docuseal:generate_sample_pdf' first"
      exit 1
    end

    puts "\n📄 Generating PDF for Trade ##{trade.id}..."
    pdf_data = TradeAgreementPdfGenerator.generate(trade)

    puts "✅ PDF generated (#{(pdf_data.bytesize / 1024.0).round(2)} KB)"
    puts "\n🚀 Attempting to create DocuSeal submission..."

    config = Rails.application.config.x.docuseal
    unless config.api_key
      puts "❌ DocuSeal API key not configured"
      puts "   Add credentials using: EDITOR=\"code --wait\" rails credentials:edit"
      exit 1
    end

    # Create Faraday connection
    connection = Faraday.new(url: config.api_url) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.headers["X-Auth-Token"] = config.api_key
      f.adapter Faraday.default_adapter
    end

    begin
      response = connection.post("/submissions/pdf") do |req|
        req.body = {
          name: "Trade Agreement ##{trade.id} (POC Test)",
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
              name: trade.buyer_name || trade.buyer_email.split("@").first.titleize
            }
          ],
          send_email: false,
          order: "preserved"
        }
      end

      if response.success?
        puts "✅ DocuSeal submission created successfully!"
        puts "\n📊 Response:"
        puts JSON.pretty_generate(response.body)

        if response.body.is_a?(Array)
          submitters = response.body
          puts "\n🔗 Signing URLs:"
          submitters.each do |submitter|
            puts "   #{submitter['role']}: #{submitter['embed_url'] || submitter['slug']}"
          end
        end
      else
        puts "❌ DocuSeal API error:"
        puts "   Status: #{response.status}"
        puts "   Body: #{response.body}"
      end
    rescue Faraday::Error => e
      puts "❌ Connection error: #{e.message}"
    end

    puts "=" * 80
  end

  desc "Test end-to-end signature workflow with Prawn PDF generation"
  task test_workflow: :environment do
    puts "=" * 80
    puts "Testing End-to-End Signature Workflow"
    puts "=" * 80

    # Find or create a draft trade
    trade = Trade.includes(:item, :seller).where(state: "draft").first

    unless trade
      puts "❌ No draft trades found. Creating a test trade..."

      account = Account.first || Account.create!(
        name: "Test Account",
        owner: User.first || User.create!(
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "Test",
          last_name: "User",
          terms_of_service: true
        )
      )

      trade = Trade.create!(
        account: account,
        seller: account.owner,
        buyer_email: "buyer@example.com",
        buyer_name: "Test Buyer",
        price_cents: 250_000,
        platform_fee_cents: 12_500,
        fee_split: "split",
        inspection_window_hours: 72,
        return_shipping_paid_by: "seller",
        seller_name: "Test Seller",
        seller_email: account.owner.email,
        seller_street1: "123 Test St",
        seller_city: "Austin",
        seller_state: "TX",
        seller_zip: "78701",
        seller_country: "United States",
        buyer_street1: "456 Buyer Ave",
        buyer_city: "Seattle",
        buyer_state: "WA",
        buyer_zip: "98101",
        buyer_country: "United States"
      )

      trade.create_item!(
        account: account,
        name: "1965 Gibson ES-335",
        description: "Vintage 1965 Gibson ES-335 in Cherry Red finish. " \
                     "This iconic semi-hollow body guitar features PAF humbuckers, " \
                     "Tune-o-matic bridge, and original Grover tuners. " \
                     "The guitar has been professionally maintained with recent fretwork " \
                     "and setup by a qualified luthier. Original case included. " \
                     "Minor finish checking consistent with age, no cracks or repairs. " \
                     "Serial number verified authentic. Plays beautifully with warm, " \
                     "singing tone that ES-335s are famous for.",
        category: "guitar",
        condition: "excellent",
        price_cents: 250_000
      )

      puts "✅ Created Trade ##{trade.id}"
    end

    puts "\n📋 Trade Details:"
    puts "   ID: #{trade.id}"
    puts "   Item: #{trade.item.name}"
    puts "   Price: #{ActionController::Base.helpers.number_to_currency(trade.price_cents / 100.0)}"
    puts "   State: #{trade.state}"
    puts "   Seller: #{trade.seller.email}"
    puts "   Buyer: #{trade.buyer_email}"

    puts "\n🚀 Triggering signature workflow..."

    begin
      # This will:
      # 1. Lock the trade
      # 2. Generate PDF with Prawn
      # 3. Upload to DocuSeal with text tags
      # 4. Create TradeDocument and DocumentSignature records
      if trade.may_send_for_signature?
        trade.send_for_signature!
        puts "✅ Signature workflow initiated successfully!"

        # Fetch the created trade document
        trade_document = trade.trade_documents.pending_status.trade_agreement_document_type.last

        if trade_document
          puts "\n📄 Trade Document Created:"
          puts "   ID: #{trade_document.id}"
          puts "   DocuSeal Submission ID: #{trade_document.docuseal_submission_id}"
          puts "   Status: #{trade_document.status}"
          puts "   Template ID: #{trade_document.docuseal_template_id || 'N/A (using Prawn)'}"

          puts "\n👥 Signatures:"
          trade_document.document_signatures.each do |sig|
            puts "   #{sig.signer_role.to_s.titleize}:"
            puts "     - Email: #{sig.signer_email}"
            puts "     - Submitter ID: #{sig.docuseal_submitter_id}"
            puts "     - Slug: #{sig.docuseal_slug}"
            puts "     - Embed URL: https://docuseal.com/s/#{sig.docuseal_slug}"
          end

          puts "\n🔗 Next Steps:"
          puts "   1. Open seller signing URL to test signature flow"
          puts "   2. Complete seller signature"
          puts "   3. Open buyer signing URL to complete"
          puts "   4. Verify webhook updates signature records"

        else
          puts "❌ Trade document not found"
        end

        puts "\n✅ Trade state updated to: #{trade.reload.state}"
      else
        puts "❌ Cannot send for signature. Current state: #{trade.state}"
        puts "   Required fields missing?" unless trade.can_send_for_signature?
      end

    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end

    puts "=" * 80
  end
end
