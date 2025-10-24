class MessageMailer < ApplicationMailer
  def new_message(recipient:, params:)
    @message = params[:message]
    @conversation = params[:conversation]
    @recipient = recipient

    # Authenticated user - direct link to conversation
    @reply_url = conversation_url(@conversation)

    mail(
      to: recipient.email,
      subject: "New message about #{@conversation.trade.item.name}"
    )
  end

  def new_message_anonymous(message)
    @message = message
    @conversation = message.conversation
    @reply_url = public_conversation_url(@conversation.buyer_token)

    mail(
      to: @conversation.buyer_email,
      subject: "New message about #{@conversation.trade.item.name}"
    )
  end
end
