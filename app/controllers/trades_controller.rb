require "bigdecimal"

class TradesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_account
  before_action :set_trades_scope, only: [:index]

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

    assign_trade_attributes

    if @trade.errors.any? || !@trade.valid?
      render :new, status: :unprocessable_content
      return
    end

    if @trade.save
      flash[:notice] = t("trades.create.success", default: "Trade draft created.")
      redirect_to trades_path
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def ensure_account
    return if current_account

    message = t("accounts.select.prompt", default: "Select an account to continue.")
    redirect_to accounts_path, alert: message
  end

  def set_trades_scope
    @trades_scope = current_account.trades.includes(:item, :buyer, :seller)
    @trade_counts = {
      total: @trades_scope.count,
      attention: @trades_scope.requiring_attention.count,
      completed: @trades_scope.completed.count
    }
  end

  def assign_trade_attributes
    permitted = trade_params

    @price_input = permitted[:price_dollars]

    @trade.assign_attributes(permitted.except(:price_dollars))
    @trade.seller = current_user
    @trade.currency ||= "USD"

    if permitted[:inspection_window_hours].present?
      @trade.inspection_window_hours = permitted[:inspection_window_hours].to_i
    end

    price_cents = parse_price_to_cents(@price_input)

    if price_cents.nil?
      if @trade.errors[:price_cents].blank?
        @trade.errors.add(:price_cents, t("trades.form.errors.price_invalid", default: "Enter a valid price"))
      end
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
end
