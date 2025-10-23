require "bigdecimal"

class TradesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_account
  before_action :set_trades_scope, only: [:index]
  before_action :set_trade, only: [:show, :attach_media, :send_to_buyer, :agree, :fund, :ship, :mark_delivered, :confirm_receipt, :accept, :reject, :send_for_signature, :cancel_signature_request, :retry_signature, :signing_url, :mark_return_shipped, :mark_return_delivered, :confirm_return_receipt, :accept_return, :reject_return_form, :reject_return]

  def index
    @pagy, @trades = pagy(@trades_scope.ordered, limit: 25)
  end

  def new
    @trade = current_account.trades.new(inspection_window_hours: 48, fee_split: "buyer", currency: "USD")
    @trade.build_item
    @price_input = params[:price] || ""
  end

  def create
    @trade = current_account.trades.new
    @trade.build_item unless @trade.item

    assign_form_attributes

    price_cents = parse_price_to_cents(@price_input)

    if price_cents.nil?
      render :new, status: :unprocessable_content
      return
    end

    if buyer_same_as_seller?(trade_params[:buyer_email])
      @trade.errors.add(:buyer_email, t("trades.service.errors.same_party", default: "Buyer and seller cannot be the same user."))
      render :new, status: :unprocessable_content
      return
    end

    result = TradeService.create_trade(
      account: current_account,
      seller: current_user,
      buyer_email: trade_params[:buyer_email],
      item_params: item_params_hash,
      trade_params: {
        price_cents: price_cents,
        fee_split: trade_params[:fee_split].presence || "buyer",
        inspection_window_hours: trade_params[:inspection_window_hours].presence&.to_i || 48,
        currency: "USD"
      }
    )

    if result[:trade]
      flash[:notice] = t("trades.create.success", default: "Trade draft created.")
      redirect_to trade_path(result[:trade])
    else
      add_service_errors(result)
      render :new, status: :unprocessable_content
    end
  end

  def show
    @price_input = format('%.2f', @trade.price) if @trade.price_cents.present?
    @image_attachments = @trade.media.select { |attachment| attachment.blob&.image? }
    @video_attachments = @trade.media.select { |attachment| attachment.blob&.video? }
    @invitation_sent = @trade.audit_logs.any? { |log| log.action == "invitation_sent" }
    @is_seller = current_user == @trade.seller
    @is_buyer = current_user == @trade.buyer
  end

  def attach_media
    attachments = Array(params.dig(:trade, :media_files)).reject(&:blank?)

    if attachments.any?
      @trade.media.attach(attachments)
      redirect_to trade_path(@trade), notice: t("trades.media.uploaded", default: "Media uploaded.")
    else
      redirect_to trade_path(@trade), alert: t("trades.media.missing", default: "Select at least one file to upload.")
    end
  end

  def send_to_buyer
    unless current_user == @trade.seller
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.not_party", default: "You are not a party to this trade.")
      return
    end

    result = TradeService.send_to_buyer(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: result[:message]
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def agree
    result = TradeService.record_agreement(@trade, current_user)

    if result[:success]
      redirect_to trade_path(@trade), notice: result[:message]
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def fund
    unless current_user == @trade.buyer
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.buyer_only", default: "Only the buyer can fund this trade")
      return
    end

    unless @trade.awaiting_funding?
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.invalid_state", default: "Trade must be awaiting funding")
      return
    end

    # Require KYC verification for buyers to prevent fraud
    unless current_user.kyc_status == "verified"
      redirect_to edit_user_registration_path, alert: t("trades.funding.kyc_required", default: "Please complete KYC verification before funding trades")
      return
    end

    # Create Stripe checkout session (collects payment method during checkout)
    result = TradeService.create_checkout_session(@trade, current_user)

    if result[:success]
      redirect_to result[:checkout_url], allow_other_host: true
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def ship
    unless current_user == @trade.seller
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.not_party", default: "You are not a party to this trade.")
      return
    end

    result = TradeService.mark_shipped(@trade, **ship_params)

    if result[:success]
      redirect_to trade_path(@trade), notice: t("trades.actions.shipped", default: "Shipment recorded.")
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def mark_delivered
    unless current_user == @trade.buyer
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.not_party", default: "You are not a party to this trade.")
      return
    end

    result = TradeService.mark_delivered(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: t("trades.actions.delivered", default: "Trade marked as delivered.")
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def confirm_receipt
    unless current_user == @trade.buyer
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.not_party", default: "You are not a party to this trade.")
      return
    end

    result = TradeService.confirm_receipt(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: t("trades.actions.receipt_confirmed", default: "Receipt confirmed. Inspection started.")
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def accept
    unless current_user == @trade.buyer
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.not_party", default: "You are not a party to this trade.")
      return
    end

    result = TradeService.accept_delivery(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: t("trades.actions.accepted", default: "Trade accepted.")
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def reject
    unless current_user == @trade.buyer
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.not_party", default: "You are not a party to this trade.")
      return
    end

    result = TradeService.reject_delivery(@trade, **reject_params)

    if result[:success]
      redirect_to trade_path(@trade), notice: t("trades.actions.rejected", default: "Trade rejected.")
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  # Signature workflow actions
  def send_for_signature
    unless current_user == @trade.seller
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.seller_only", default: "Only the seller can send for signature")
      return
    end

    result = TradeService.send_for_signature(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: t("trades.signature.sent", default: "Trade sent for signature")
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def cancel_signature_request
    unless current_user == @trade.seller
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.seller_only", default: "Only the seller can cancel signature requests")
      return
    end

    result = TradeService.cancel_signature_request(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: result[:message]
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def retry_signature
    unless current_user == @trade.seller
      redirect_to trade_path(@trade), alert: t("trades.actions.errors.seller_only", default: "Only the seller can retry signature")
      return
    end

    if @trade.may_restart_signature_process?
      @trade.restart_signature_process!
      redirect_to trade_path(@trade), notice: t("trades.signature.retried", default: "Trade returned to draft. You can now send for signature again.")
    else
      redirect_to trade_path(@trade), alert: t("trades.signature.cannot_retry", default: "Cannot retry signature")
    end
  end

  def signing_url
    result = TradeService.get_signing_url(@trade, current_user)
    render json: result
  end

  # Return workflow actions
  def mark_return_shipped
    result = TradeService.mark_return_shipped(@trade, **ship_params)

    if result[:success]
      redirect_to trade_path(@trade), notice: "Return shipment recorded."
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def mark_return_delivered
    result = TradeService.mark_return_delivered(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: "Return marked as delivered."
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def confirm_return_receipt
    result = TradeService.confirm_return_receipt(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: "Return receipt confirmed. Please inspect the item."
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def accept_return
    result = TradeService.accept_return(@trade)

    if result[:success]
      redirect_to trade_path(@trade), notice: result[:message]
    else
      redirect_to trade_path(@trade), alert: result[:error]
    end
  end

  def reject_return_form
    # Show form for seller to provide rejection reason
    unless @trade.may_reject_return?
      redirect_to trade_path(@trade), alert: "Cannot reject return in current state"
      return
    end

    unless current_user == @trade.seller
      redirect_to trade_path(@trade), alert: "Only the seller can reject returns"
      return
    end
  end

  def reject_return
    unless current_user == @trade.seller
      redirect_to trade_path(@trade), alert: "Only the seller can reject returns"
      return
    end

    # Create support request with dispute type
    support_request = current_account.support_requests.new(
      trade: @trade,
      opened_by: current_user,
      subject: "Return Rejection - Trade ##{@trade.id}",
      request_type: "dispute",
      status: "open"
    )

    # Create initial message with rejection reason
    message = support_request.support_messages.build(
      body: params[:rejection_reason],
      author: current_user,
      sent_via: "web"
    )

    if support_request.save && message.save
      # Attach files if provided
      if params[:files].present?
        message.files.attach(params[:files])
      end

      # Transition trade to disputed state
      result = TradeService.reject_return(@trade, rejection_reason: params[:rejection_reason])

      if result[:success]
        redirect_to trade_path(@trade), notice: "Return rejected. Dispute case created."
      else
        # If state transition fails, delete the support request
        support_request.destroy
        redirect_to reject_return_form_trade_path(@trade), alert: result[:error]
      end
    else
      redirect_to reject_return_form_trade_path(@trade), alert: "Please provide a rejection reason"
    end
  end

  private

  def ensure_account
    return if current_account

    message = t("accounts.select.prompt", default: "Select an account to continue.")
    redirect_to accounts_path, alert: message
  end

  def set_trades_scope
    # Show trades where user is buyer OR seller OR trade belongs to current account
    @trades_scope = Trade.where(buyer_id: current_user.id)
                         .or(Trade.where(seller_id: current_user.id))
                         .or(Trade.where(account_id: current_account.id))
                         .includes(:item, :buyer, :seller)
                         .distinct

    @trade_counts = {
      total: @trades_scope.count,
      attention: @trades_scope.requiring_attention.count,
      completed: @trades_scope.completed.count
    }
  end

  def set_trade
    # Allow access if user is buyer, seller, or trade belongs to current account
    @trade = Trade.where(id: params[:id])
                  .where("buyer_id = ? OR seller_id = ? OR account_id = ?",
                         current_user.id, current_user.id, current_account.id)
                  .includes(:item, :buyer, :seller, :shipments, :audit_logs, media_attachments: :blob)
                  .first!
  end

  def assign_trade_attributes
    permitted = trade_params
    @price_input = permitted[:price_dollars]

    @trade.assign_attributes(permitted.except(:price_dollars))
    @trade.seller = current_user
    @trade.currency ||= "USD"
    @trade.inspection_window_hours = permitted[:inspection_window_hours].to_i if permitted[:inspection_window_hours].present?

    price_cents = parse_price_to_cents(@price_input)

    if price_cents.nil?
      @trade.errors.add(:price_cents, t("trades.form.errors.price_invalid", default: "Enter a valid price")) if @trade.errors[:price_cents].blank?
    else
      @trade.price_cents = price_cents
      @trade.item.price_cents = price_cents if @trade.item
    end
  end

  def parse_price_to_cents(value)
    return nil if value.blank?

    amount = BigDecimal(value.to_s)
    cents = (amount * 100).round

    if cents < 2000 || cents > 1_500_000
      @trade.errors.add(:price_cents, t("trades.form.errors.price_range", default: "Price must be between $20.00 and $15,000.00"))
      return nil
    end

    cents
  rescue ArgumentError
    nil
  end

  def trade_params
    params.require(:trade).permit(
      :buyer_email,
      :fee_split,
      :inspection_window_hours,
      :price_dollars,
      item_attributes: [:name, :description, :category, :condition]
    )
  end

  def ship_params
    params.require(:trade).permit(:carrier, :tracking_number).to_h.symbolize_keys
  end

  def reject_params
    params.require(:trade).permit(:reason_category, :reason_text).to_h.symbolize_keys
  end

  def assign_form_attributes
    permitted = trade_params
    @price_input = permitted[:price_dollars]

    @trade.assign_attributes(
      buyer_email: permitted[:buyer_email],
      fee_split: permitted[:fee_split],
      inspection_window_hours: permitted[:inspection_window_hours].presence,
      currency: "USD",
      account: current_account
    )

    if permitted[:item_attributes]
      item = (@trade.item || @trade.build_item)
      item.assign_attributes(permitted[:item_attributes].to_h)
      item.account = current_account
    end
  end

  def item_params_hash
    attrs = trade_params[:item_attributes]
    attrs ? attrs.to_h.symbolize_keys : {}
  end

  def buyer_same_as_seller?(email)
    email.present? && current_user.email.casecmp?(email.to_s.strip)
  end

  def add_service_errors(result)
    if result[:errors].present?
      result[:errors].each do |attribute, messages|
        Array(messages).each { |message| @trade.errors.add(attribute, message) }
      end
    end

    if result[:error].present?
      @trade.errors.add(:base, result[:error])
    end
  end
end
