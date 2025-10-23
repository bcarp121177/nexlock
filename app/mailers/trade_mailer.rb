class TradeMailer < ApplicationMailer
  def funded(recipient, notification)
    @trade = notification.params[:trade]
    @recipient = recipient

    mail(
      to: recipient.email,
      subject: "Trade ##{@trade.id} - Payment Received"
    )
  end

  def shipped(recipient, notification)
    @trade = notification.params[:trade]
    @recipient = recipient
    @shipment = @trade.shipments.where(direction: 'forward').order(created_at: :desc).first

    mail(
      to: recipient.email,
      subject: "Trade ##{@trade.id} - Item Shipped"
    )
  end

  def delivered(recipient, notification)
    @trade = notification.params[:trade]
    @recipient = recipient
    @shipment = @trade.shipments.where(direction: 'forward').order(created_at: :desc).first

    mail(
      to: recipient.email,
      subject: "Trade ##{@trade.id} - Package Delivered"
    )
  end

  def accepted(recipient, notification)
    @trade = notification.params[:trade]
    @recipient = recipient

    mail(
      to: recipient.email,
      subject: "Trade ##{@trade.id} - Item Accepted"
    )
  end

  def rejected(recipient, notification)
    @trade = notification.params[:trade]
    @recipient = recipient
    @return_shipment = @trade.shipments.where(direction: 'return').order(created_at: :desc).first

    mail(
      to: recipient.email,
      subject: "Trade ##{@trade.id} - Item Rejected"
    )
  end

  def return_accepted(recipient, notification)
    @trade = notification.params[:trade]
    @recipient = recipient

    mail(
      to: recipient.email,
      subject: "Trade ##{@trade.id} - Return Accepted"
    )
  end

  def refunded(recipient, notification)
    @trade = notification.params[:trade]
    @recipient = recipient
    @refund_amount = @trade.calculate_refund_amount

    mail(
      to: recipient.email,
      subject: "Trade ##{@trade.id} - Refund Processed"
    )
  end
end
