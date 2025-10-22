class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @stripe_result = stripe_service.account_status
    @stripe_account = @stripe_result.success? ? @stripe_result.data : nil
    @stripe_error = @stripe_result.success? ? nil : @stripe_result.error

    update_user_kyc_status(@stripe_account) if @stripe_account.present?
  end

  def start_stripe_onboarding
    business_type = params[:business_type].presence || "individual"
    result = stripe_service.onboarding_link(business_type: business_type)

    if result.success?
      redirect_to result.data[:url], allow_other_host: true, status: :see_other
    else
      redirect_to settings_path, alert: result.error || t("settings.stripe.start_failed", default: "Unable to start onboarding.")
    end
  end

  private

  def stripe_service
    @stripe_service ||= StripeConnectService.new(current_user)
  end

  def update_user_kyc_status(account)
    return unless account

    new_status = if account[:payouts_enabled] && account[:charges_enabled]
      "verified"
    elsif Array(account.dig(:requirements, :currently_due)).any? || Array(account.dig(:requirements, :past_due)).any?
      "pending"
    else
      current_user.kyc_status
    end

    return if new_status == current_user.kyc_status

    current_user.update(kyc_status: new_status)
  rescue => e
    Rails.logger.error "Failed to update user KYC status: #{e.message}"
  end

end
