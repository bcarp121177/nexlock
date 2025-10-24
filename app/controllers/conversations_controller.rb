class ConversationsController < ApplicationController
  before_action :set_conversation, only: [:show]
  before_action :authorize_access, only: [:show]

  def index
    @conversations = Conversation.for_user(current_user).ordered.includes(:trade, :messages)
  end

  def show
    @messages = @conversation.messages.ordered.includes(:sender_user)
    @message = @conversation.messages.new
    mark_messages_as_read
  end

  def create
    # Find trade by ID (public access, no authentication required)
    @trade = Trade.find(params[:conversation][:trade_id])

    # Extract initial_message before creating conversation
    initial_message = params[:conversation][:initial_message]

    @conversation = @trade.conversations.new(buyer_email: params[:conversation][:buyer_email])
    @conversation.seller = @trade.seller

    if @conversation.save
      # Create the initial message if provided
      if initial_message.present?
        @conversation.messages.create!(
          body: initial_message,
          sender_type: 'buyer',
          sender_email: @conversation.buyer_email
        )
      end

      # Stay on current page with success message
      redirect_back fallback_location: root_path, notice: "Your message has been sent to the seller. They will reply via email."
    else
      redirect_back fallback_location: root_path, alert: "Error sending message: #{@conversation.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_conversation
    if params[:token].present?
      @conversation = Conversation.find_by!(buyer_token: params[:token])
    else
      @conversation = Conversation.find(params[:id])
    end
  end

  def authorize_access
    # Allow if current_user is seller or buyer_user
    # OR if params[:token] matches conversation.buyer_token (anonymous access)
    unless user_signed_in? && (@conversation.seller == current_user || @conversation.buyer_user == current_user) ||
           params[:token] == @conversation.buyer_token
      redirect_to root_path, alert: "Access denied"
    end
  end

  def mark_messages_as_read
    if user_signed_in? && current_user == @conversation.seller
      @conversation.messages.where(sender_type: 'buyer', read_at: nil).update_all(read_at: Time.current)
    elsif params[:token] == @conversation.buyer_token
      @conversation.messages.where(sender_type: 'seller', read_at: nil).update_all(read_at: Time.current)
    end
  end

  def conversation_params
    params.require(:conversation).permit(:buyer_email)
  end
end
