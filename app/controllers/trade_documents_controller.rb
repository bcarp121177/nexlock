class TradeDocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trade
  before_action :set_trade_document, only: [:show, :download]
  before_action :authorize_access!

  def index
    @trade_documents = @trade.trade_documents
                             .includes(:document_signatures)
                             .order(created_at: :desc)
  end

  def show
    # Show document details with signature status
  end

  def download
    if @trade_document.signed_document_url.present?
      redirect_to @trade_document.signed_document_url, allow_other_host: true
    elsif @trade.signed_agreement.attached?
      redirect_to rails_blob_path(@trade.signed_agreement, disposition: "attachment")
    else
      redirect_to trade_path(@trade), alert: t("trade_documents.download.not_available", default: "Signed document not available yet")
    end
  end

  private

  def set_trade
    @trade = current_account.trades.find(params[:trade_id])
  end

  def set_trade_document
    @trade_document = @trade.trade_documents.find(params[:id])
  end

  def authorize_access!
    unless @trade.buyer_id == current_user.id || @trade.seller_id == current_user.id
      redirect_to root_path, alert: t("trade_documents.access_denied", default: "Access denied")
    end
  end
end
