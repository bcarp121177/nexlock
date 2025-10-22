class StripeService
  class << self
    def create_onboarding_link(user, business_type: "individual")
      ensure_connect_account!(user, business_type: business_type)

      collect_param = business_type == "individual" ? "eventually_due" : "currently_due"

      account_link = Stripe::AccountLink.create(
        account: user.stripe_connect_id,
        refresh_url: settings_url(refresh: true),
        return_url: settings_url(success: true),
        type: "account_onboarding",
        collect: collect_param
      )

      unless valid_redirect_host?(account_link.url)
        Rails.logger.error "Invalid redirect URL from Stripe: #{account_link.url}"
        return { success: false, error: I18n.t("settings.stripe.invalid_redirect", default: "Unable to start onboarding. Contact support.") }
      end

      { success: true, url: account_link.url }
    rescue Stripe::StripeError => e
      Rails.logger.error "Error creating Stripe onboarding link: #{e.message}"
      { success: false, error: e.message }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Error saving Stripe account for user ##{user.id}: #{e.record.errors.full_messages.to_sentence}"
      { success: false, error: e.record.errors.full_messages.to_sentence }
    end

    def get_account_status(stripe_account_id)
      return { success: false, error: "No Stripe account ID provided" } unless stripe_account_id.present?

      account = Stripe::Account.retrieve(stripe_account_id)

      {
        success: true,
        account: {
          id: account.id,
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          details_submitted: account.details_submitted,
          requirements: {
            currently_due: account.requirements.currently_due,
            eventually_due: account.requirements.eventually_due,
            past_due: account.requirements.past_due
          }
        }
      }
    rescue Stripe::StripeError => e
      Rails.logger.error "Error retrieving Stripe account #{stripe_account_id}: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def ensure_connect_account!(user, business_type: "individual")
      return if user.stripe_connect_id.present?

      account_params = {
        type: "express",
        country: "US",
        email: user.email,
        capabilities: {
          transfers: { requested: true }
        },
        business_type: business_type,
        metadata: {
          user_id: user.id
        }
      }

      if business_type == "individual"
        account_params[:business_profile] = {
          mcc: "5734",
          product_description: "Peer-to-peer escrow marketplace transactions"
        }
      end

      account = Stripe::Account.create(account_params)
      user.update!(stripe_connect_id: account.id)
    rescue Stripe::StripeError => e
      Rails.logger.error "Error creating Stripe Connect account: #{e.message}"
      raise
    end

    def settings_url(**params)
      Rails.application.routes.url_helpers.settings_url(default_url_options.merge(params))
    end

    def default_url_options
      host = ENV["APP_HOST"].presence || Jumpstart.config.domain.presence || default_host
      protocol = ENV["APP_PROTOCOL"].presence || (host&.include?("localhost") ? "http" : "https")
      port = ENV["APP_PORT"].presence

      {}.tap do |opts|
        opts[:host] = host
        opts[:protocol] = protocol
        opts[:port] = port if port.present? && !host.to_s.include?(":")
      end
    end

    def default_host
      port = ENV.fetch("PORT", 3000)
      "localhost:#{port}"
    end

    def valid_redirect_host?(url)
      return false if url.blank?

      uri = URI.parse(url)
      ALLOWED_REDIRECT_HOSTS.include?(uri.host)
    rescue URI::InvalidURIError
      false
    end

    # Create payout/transfer to seller's Connect account
    def create_payout(trade, amount_cents: nil)
      unless trade.seller.can_receive_payouts?
        return { success: false, error: "Seller cannot receive payouts. KYC not complete." }
      end

      # Calculate payout amount (price minus seller's fees)
      payout_amount = amount_cents || TradeService.calculate_payout_amount(trade)

      begin
        transfer = Stripe::Transfer.create(
          amount: payout_amount,
          currency: trade.currency.downcase,
          destination: trade.seller.stripe_connect_id,
          metadata: {
            trade_id: trade.id,
            seller_id: trade.seller_id,
            buyer_id: trade.buyer_id,
            item_name: trade.item&.name,
            platform_fee_cents: trade.platform_fee_cents
          },
          description: "Payout for #{trade.item&.name || 'item'}"
        )

        # Create payout record
        payout = trade.build_payout(
          account: trade.account,
          seller: trade.seller,
          amount_cents: payout_amount,
          provider: 'stripe',
          status: 'pending',
          transfer_id: transfer.id
        )

        if payout.save
          Rails.logger.info "Payout created: #{transfer.id} for trade #{trade.id}"
          { success: true, transfer: transfer, payout: payout }
        else
          { success: false, error: payout.errors.full_messages.join(", ") }
        end
      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe error creating payout: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
