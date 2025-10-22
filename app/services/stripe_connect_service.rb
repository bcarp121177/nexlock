class StripeConnectService
  ALLOWED_BUSINESS_TYPES = %w[individual company].freeze

  Result = Struct.new(:success?, :data, :error, keyword_init: true)

  def initialize(user)
    @user = user
  end

  def account_status
    return Result.new(success?: false, error: :missing_account) unless user.stripe_connect_id.present?

    account = StripeService.get_account_status(user.stripe_connect_id)
    return Result.new(success?: false, error: account[:error]) unless account[:success]

    Result.new(success?: true, data: account[:account])
  end

  def onboarding_link(business_type: "individual")
    business_type = business_type.to_s
    return Result.new(success?: false, error: I18n.t("settings.stripe.invalid_business_type", default: "Invalid business type")) unless ALLOWED_BUSINESS_TYPES.include?(business_type)

    result = StripeService.create_onboarding_link(user, business_type: business_type)
    return Result.new(success?: false, error: result[:error]) unless result[:success]

    Result.new(success?: true, data: { url: result[:url] })
  end

  private

  attr_reader :user
end
