module TradesHelper
  STATE_BADGE_VARIANTS = {
    draft: :info,
    awaiting_seller_signature: :warning,
    awaiting_buyer_signature: :warning,
    signature_deadline_missed: :danger,
    awaiting_funding: :info,
    funded: :info,
    shipped: :info,
    delivered_pending_confirmation: :warning,
    inspection: :warning,
    accepted: :success,
    released: :success,
    rejected: :danger,
    return_in_transit: :warning,
    returned: :info,
    refunded: :danger,
    disputed: :danger,
    resolved_release: :success,
    resolved_refund: :success,
    resolved_split: :success
  }.freeze

  def trade_state_badge(trade)
    variant = STATE_BADGE_VARIANTS[trade.state.to_sym] || :info
    classes = ["badge-app"]
    classes << "badge-app-success" if variant == :success
    classes << "badge-app-warning" if variant == :warning
    classes << "badge-app-danger" if variant == :danger
    classes << "badge-app-info" if variant == :info

    content_tag(:span, trade.formatted_state, class: classes.join(" "))
  end

  def trade_price(trade)
    number_to_currency(trade.price)
  end
end
