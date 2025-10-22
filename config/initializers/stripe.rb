stripe_secret = ENV["STRIPE_SECRET_KEY"].presence || Rails.application.credentials.dig(:stripe, :private_key)
stripe_public = ENV["STRIPE_PUBLISHABLE_KEY"].presence || Rails.application.credentials.dig(:stripe, :public_key)
webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].presence || Rails.application.credentials.dig(:stripe, :signing_secret)

Stripe.api_key = stripe_secret if stripe_secret.present?

StripeConfiguration = Struct.new(:public_key, :webhook_secret)
Rails.application.config.x.stripe = StripeConfiguration.new(stripe_public, webhook_secret)
