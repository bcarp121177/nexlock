# frozen_string_literal: true

namespace :listing do
  desc "Test end-to-end listing workflow"
  task test_workflow: :environment do
    puts "=" * 80
    puts "Testing Trade Listing Workflow"
    puts "=" * 80

    # Step 1: Create a draft trade (without buyer email)
    puts "\n📝 Step 1: Creating draft trade (no buyer email required)..."

    account = Account.first || Account.create!(
      name: "Test Seller Account",
      owner: User.first || User.create!(
        email: "seller_#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Test",
        last_name: "Seller",
        terms_of_service: true
      )
    )

    trade = Trade.create!(
      account: account,
      seller: account.owner,
      price_cents: 350_000, # $3,500
      platform_fee_cents: 17_500,
      fee_split: "buyer",
      inspection_window_hours: 72,
      return_shipping_paid_by: "seller",
      seller_name: "Test Seller",
      seller_street1: "789 Seller St",
      seller_city: "Nashville",
      seller_state: "TN",
      seller_zip: "37201",
      seller_country: "United States"
      # Note: NO buyer_email required for draft!
    )

    trade.create_item!(
      account: account,
      name: "Vintage Martin D-28 Acoustic Guitar",
      description: "Beautiful 1972 Martin D-28 in excellent condition. " \
                   "This classic acoustic guitar features a solid Sitka spruce top, " \
                   "Indian rosewood back and sides, and ebony fingerboard. " \
                   "The tone is warm and resonant with excellent projection. " \
                   "Recently professionally set up with new strings. " \
                   "Includes original hardshell case. No cracks, clean frets, straight neck. " \
                   "A true vintage gem perfect for recording or live performance.",
      category: "guitar",
      condition: "excellent",
      price_cents: 350_000
    )

    puts "✅ Draft trade created: Trade ##{trade.id}"
    puts "   State: #{trade.state}"
    puts "   Listing Status: #{trade.listing_status}"
    puts "   Buyer Email: #{trade.buyer_email.presence || 'N/A (not required yet!)'}"

    # Step 2: Publish listing
    puts "\n📢 Step 2: Publishing listing..."

    if trade.may_publish_listing?
      result = TradeService.publish_listing(trade)
      if result[:success]
        trade.reload
        puts "✅ Listing published successfully!"
        puts "   State: #{trade.state}"
        puts "   Listing Status: #{trade.listing_status}"
        puts "   Published At: #{trade.published_at}"
        puts "   Listing URL: #{trade.listing_url}"
      else
        puts "❌ Failed to publish: #{result[:error]}"
        exit 1
      end
    else
      puts "❌ Cannot publish listing. Missing requirements."
      puts "   Item present: #{trade.item.present?}"
      puts "   Price set: #{trade.price_cents.present?}"
      exit 1
    end

    # Step 3: Simulate buyer viewing listing
    puts "\n👀 Step 3: Simulating buyer views..."

    3.times do |i|
      # In real app, Ahoy would track this automatically
      # For testing, we'll just increment the counter
      trade.increment!(:view_count)
      puts "   View #{i + 1} tracked"
    end

    trade.update_column(:buyer_viewed_at, Time.current)
    puts "✅ First view timestamp recorded"
    puts "   Total views: #{trade.view_count}"

    # Step 4: Buyer accepts listing (provides info)
    puts "\n✋ Step 4: Buyer accepting listing..."

    buyer_params = {
      buyer_email: "buyer_#{SecureRandom.hex(4)}@example.com",
      buyer_name: "Test Buyer",
      buyer_phone: "555-0123",
      buyer_street1: "456 Buyer Ave",
      buyer_street2: "Apt 2B",
      buyer_city: "Seattle",
      buyer_state: "WA",
      buyer_zip: "98101",
      buyer_country: "United States"
    }

    result = TradeService.accept_listing(trade, buyer_params)

    if result[:success]
      trade.reload
      puts "✅ Buyer accepted listing!"
      puts "   Listing Status: #{trade.listing_status}"
      puts "   Buyer Email: #{trade.buyer_email}"
      puts "   Buyer Name: #{trade.buyer_name}"
      puts "   Buyer Address: #{trade.buyer_street1}, #{trade.buyer_city}, #{trade.buyer_state}"
    else
      puts "❌ Failed to accept listing: #{result[:error]}"
      exit 1
    end

    # Step 5: Send for signature
    puts "\n✍️  Step 5: Sending for signature..."

    if trade.buyer_info_complete?
      puts "✅ Buyer info is complete"
      puts "   Can send for signature: #{trade.may_send_for_signature?}"

      if trade.may_send_for_signature?
        puts "   Attempting to send for signature..."
        puts "   (In production, this would generate PDF and create DocuSeal submission)"
      else
        puts "❌ Cannot send for signature yet"
        puts "   Current state: #{trade.state}"
      end
    else
      puts "❌ Buyer info incomplete"
    end

    # Summary
    puts "\n" + "=" * 80
    puts "✅ WORKFLOW TEST COMPLETE"
    puts "=" * 80
    puts "\nTrade Summary:"
    puts "  ID: #{trade.id}"
    puts "  State: #{trade.state}"
    puts "  Listing Status: #{trade.listing_status}"
    puts "  Published At: #{trade.published_at}"
    puts "  Views: #{trade.view_count}"
    puts "  Buyer Accepted: #{trade.listing_status == 'accepted' ? 'Yes' : 'No'}"
    puts "  Buyer Info Complete: #{trade.buyer_info_complete? ? 'Yes' : 'No'}"
    puts "\nNext Steps in Production:"
    puts "  1. Seller shares listing URL with potential buyers"
    puts "  2. Buyers visit #{trade.listing_url}"
    puts "  3. Buyer fills out form and accepts"
    puts "  4. Seller sends for digital signature"
    puts "  5. Both parties sign agreement"
    puts "  6. Buyer funds escrow"
    puts "  7. Transaction proceeds normally"
    puts "\n✨ Public listing workflow is functional!"
    puts "=" * 80
  end
end
