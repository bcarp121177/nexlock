class TradeMailer < ApplicationMailer
  def buyer_signature_needed
    @trade = params[:trade]
    @recipient = params[:recipient]
    @trade_document = @trade.trade_documents.order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Agreement Ready for Signature"
    )
  end

  def signature_deadline_reminder
    @trade = params[:trade]
    @recipient = params[:recipient]
    @trade_document = @trade.trade_documents.order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "⚠️ Trade ##{@trade.id} - Agreement Expires in 24 Hours"
    )
  end

  def funding_required
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Payment Required"
    )
  end

  def funded
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Payment Received - Ship Item"
    )
  end

  def shipped
    @trade = params[:trade]
    @recipient = params[:recipient]
    @shipment = @trade.shipments.where(direction: 'forward').order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Item Shipped"
    )
  end

  def delivered
    @trade = params[:trade]
    @recipient = params[:recipient]
    @shipment = @trade.shipments.where(direction: 'forward').order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Package Delivered"
    )
  end

  def accepted
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Item Accepted"
    )
  end

  def rejected
    @trade = params[:trade]
    @recipient = params[:recipient]
    @return_shipment = @trade.shipments.where(direction: 'return').order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Item Rejected"
    )
  end

  def return_accepted
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Return Accepted"
    )
  end

  def refunded
    @trade = params[:trade]
    @recipient = params[:recipient]
    @refund_amount = @trade.calculate_refund_amount

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Refund Processed"
    )
  end

  def receipt_confirmed
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Buyer Confirmed Receipt"
    )
  end

  def return_shipped
    @trade = params[:trade]
    @recipient = params[:recipient]
    @shipment = @trade.shipments.where(direction: 'return').order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Return Shipment In Transit"
    )
  end

  def return_delivered
    @trade = params[:trade]
    @recipient = params[:recipient]
    @shipment = @trade.shipments.where(direction: 'return').order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Return Package Delivered"
    )
  end

  def return_receipt_confirmed
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Return Received, Inspection Started"
    )
  end

  def return_rejected
    @trade = params[:trade]
    @recipient = params[:recipient]
    @support_request = @trade.support_requests.where(request_type: 'dispute').order(created_at: :desc).first

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Return Rejected, Dispute Opened"
    )
  end

  def dispute_resolved_release
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Dispute Resolved"
    )
  end

  def dispute_resolved_refund
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Dispute Resolved, Refund Approved"
    )
  end

  def dispute_resolved_split
    @trade = params[:trade]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Trade ##{@trade.id} - Dispute Resolved, Partial Refund"
    )
  end
end
