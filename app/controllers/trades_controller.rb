class TradesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_account
  before_action :set_trades_scope, only: [:index]

  def index
    @pagy, @trades = pagy(@trades_scope.ordered, limit: 25)
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
end
