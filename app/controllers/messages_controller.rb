class MessagesController < ApplicationController
  before_action :set_conversation
  before_action :authorize_access

  def create
    @message = @conversation.messages.new(message_params)

    # Set sender info based on who's sending
    if user_signed_in? && current_user == @conversation.seller
      @message.sender_type = 'seller'
      @message.sender_user = current_user
      @message.sender_email = current_user.email
    else
      @message.sender_type = 'buyer'
      @message.sender_email = @conversation.buyer_email
    end

    if @message.save
      redirect_to conversation_path(@conversation, token: params[:token]), notice: "Message sent"
    else
      redirect_to conversation_path(@conversation, token: params[:token]), alert: "Error sending message"
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  def authorize_access
    unless user_signed_in? && (@conversation.seller == current_user || @conversation.buyer_user == current_user) ||
           params[:token] == @conversation.buyer_token
      redirect_to root_path, alert: "Access denied"
    end
  end

  def message_params
    params.require(:message).permit(:body)
  end
end
