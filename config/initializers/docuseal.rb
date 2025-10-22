require "ostruct"

# Load DocuSeal configuration from Rails credentials
Rails.application.config.x.docuseal = OpenStruct.new(
  api_key: Rails.application.credentials.dig(:docuseal, :api_key),
  api_url: Rails.application.credentials.dig(:docuseal, :api_url) || "https://api.docuseal.com",
  webhook_secret: Rails.application.credentials.dig(:docuseal, :webhook_secret),
  trade_agreement_template_id: Rails.application.credentials.dig(:docuseal, :trade_agreement_template_id)
)

# Validation checks (warn in development, raise in production)
Rails.application.config.after_initialize do
  config = Rails.application.config.x.docuseal

  missing = []
  missing << "api_key" if config.api_key.blank?
  missing << "trade_agreement_template_id" if config.trade_agreement_template_id.blank?
  missing << "webhook_secret" if config.webhook_secret.blank? && Rails.env.production?

  if missing.any?
    message = "DocuSeal configuration missing: #{missing.join(", ")}"

    if Rails.env.production?
      raise message
    else
      Rails.logger.warn "⚠️  #{message}"
      Rails.logger.warn "   Add credentials using: EDITOR=\"code --wait\" rails credentials:edit --environment #{Rails.env}"
      Rails.logger.warn "   See config/credentials/docuseal_template.yml for structure"
    end
  else
    Rails.logger.info "✓ DocuSeal configured successfully"
    Rails.logger.info "  - API URL: #{config.api_url}"
    Rails.logger.info "  - Template ID: #{config.trade_agreement_template_id}"
    Rails.logger.info "  - Webhook secret: #{config.webhook_secret.present? ? "configured" : "not configured"}"
  end
end
