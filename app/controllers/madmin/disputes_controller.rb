module Madmin
  class DisputesController < Madmin::ResourceController
    before_action :set_dispute, only: [:resolve_refund, :resolve_release, :resolve_split]

    def resolve_refund
      trade = @dispute.trade

      if trade.may_resolve_with_refund?
        trade.resolve_with_refund!
        redirect_to madmin_dispute_path(@dispute), notice: "Dispute resolved - Full refund to buyer"
      else
        redirect_to madmin_dispute_path(@dispute), alert: "Cannot resolve dispute in current state: #{trade.state}"
      end
    rescue => e
      redirect_to madmin_dispute_path(@dispute), alert: "Error: #{e.message}"
    end

    def resolve_release
      trade = @dispute.trade

      if trade.may_resolve_with_release?
        trade.resolve_with_release!
        redirect_to madmin_dispute_path(@dispute), notice: "Dispute resolved - Funds released to seller"
      else
        redirect_to madmin_dispute_path(@dispute), alert: "Cannot resolve dispute in current state: #{trade.state}"
      end
    rescue => e
      redirect_to madmin_dispute_path(@dispute), alert: "Error: #{e.message}"
    end

    def resolve_split
      trade = @dispute.trade
      seller_percentage = params[:seller_percentage]&.to_i || 50

      # Store resolution data
      @dispute.update!(resolution_data: { seller_percentage: seller_percentage })

      if trade.may_resolve_with_split?
        trade.resolve_with_split!
        redirect_to madmin_dispute_path(@dispute), notice: "Dispute resolved - Split #{seller_percentage}% to seller, #{100 - seller_percentage}% to buyer"
      else
        redirect_to madmin_dispute_path(@dispute), alert: "Cannot resolve dispute in current state: #{trade.state}"
      end
    rescue => e
      redirect_to madmin_dispute_path(@dispute), alert: "Error: #{e.message}"
    end

    private

    def set_dispute
      @dispute = Dispute.find(params[:id])
    end
  end
end
