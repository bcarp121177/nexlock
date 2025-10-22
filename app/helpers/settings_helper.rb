module SettingsHelper
  def stripe_payout_status_badge(account)
    return content_tag(:span, t("settings.stripe.not_connected", default: "Not connected"), class: "badge-app badge-app-warning") unless account

    if account[:payouts_enabled]
      content_tag(:span, t("settings.stripe.payouts_enabled", default: "Payouts enabled"), class: "badge-app badge-app-success")
    else
      content_tag(:span, t("settings.stripe.action_required", default: "Action required"), class: "badge-app badge-app-warning")
    end
  end

  def stripe_requirements(account)
    return [] unless account

    account.fetch(:requirements, {}).fetch(:currently_due, [])
  end
end
