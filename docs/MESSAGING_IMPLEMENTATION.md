# In-App Messaging System Implementation

## Status: In Progress

### Completed:
- ✅ Database migrations (Conversations and Messages tables)
- ✅ Conversation model with associations and validations
- ✅ Message model with associations and validations
- ✅ Added conversations association to Trade model

### Next Steps:

#### 1. Create Controllers

**ConversationsController:**
```ruby
# app/controllers/conversations_controller.rb
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
    # For authenticated sellers responding to conversations
    @conversation = current_account.trades.find(params[:trade_id]).conversations.new(conversation_params)
    @conversation.seller = current_user

    if @conversation.save
      redirect_to @conversation
    else
      # Handle error
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find_by!(id: params[:id])
                                 .or(Conversation.find_by!(buyer_token: params[:token]))
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
```

**MessagesController:**
```ruby
# app/controllers/messages_controller.rb
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
```

#### 2. Routes

```ruby
# config/routes.rb
resources :conversations, only: [:index, :show, :create] do
  resources :messages, only: [:create]
end

# Public conversation access via token
get '/c/:token', to: 'conversations#show', as: :public_conversation
```

#### 3. Views

**Inbox (conversations/index.html.erb):**
- List all conversations for current_user
- Show unread count
- Link to each conversation
- Show last message preview

**Conversation Thread (conversations/show.html.erb):**
- Display all messages in conversation
- Message composer form
- Show trade context (item, price, etc.)
- Works for both authenticated and anonymous users (via token)

**New Conversation Form (on listing page):**
- Email field
- Initial message field
- Creates conversation and first message

#### 4. Noticed Integration

```ruby
# app/notifications/new_message_notification.rb
class NewMessageNotification < Noticed::Event
  deliver_by :database
  deliver_by :email, mailer: 'MessageMailer', if: :email_notifications_enabled?

  param :message
  param :conversation

  def message
    "New message about #{params[:conversation].trade.item.name}"
  end

  def url
    conversation_path(params[:conversation])
  end

  private

  def email_notifications_enabled?
    recipient.notification_setting&.email_notifications?
  end
end
```

Update Message model's `send_notification`:
```ruby
def send_notification
  recipient = sender_type == 'seller' ? conversation.seller : (conversation.buyer_user || nil)

  if recipient
    NewMessageNotification.with(message: self, conversation: conversation).deliver(recipient)
  end

  # Also send email to anonymous buyer if they don't have account
  if sender_type == 'seller' && conversation.buyer_user.nil?
    MessageMailer.new_message_anonymous(self).deliver_later
  end
end
```

#### 5. Email Templates

**MessageMailer:**
```ruby
# app/mailers/message_mailer.rb
class MessageMailer < ApplicationMailer
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
```

#### 6. Update Public Listing

Replace email button with "Message Seller" button that shows a form:
- Buyer email input
- Message textarea
- Submit creates Conversation + first Message
- Redirects to public conversation URL (with token)

## Database Schema

### Conversations
- trade_id (references trades)
- seller_id + seller_type (polymorphic to User)
- buyer_user_id (nullable, references users)
- buyer_email (required)
- buyer_token (unique, for anonymous access)
- status (active/archived/converted_to_buyer)
- timestamps

### Messages
- conversation_id
- sender_type (seller/buyer)
- sender_user_id (nullable, references users)
- sender_email (required for display)
- body (text, required)
- read_at (nullable datetime)
- timestamps

## Security Considerations

1. **Anonymous Access**: Buyer token must be secure (urlsafe_base64(32))
2. **Authorization**: Check user is participant OR has valid token
3. **Rate Limiting**: Add rate limiting to prevent spam
4. **Input Validation**: Sanitize message body, limit length
5. **Email Verification**: Consider verifying buyer_email on first message

## Future Enhancements

- File attachments
- Turbo Streams for real-time updates
- Read receipts
- Typing indicators
- Mark conversation as spam/block
- Search conversations
- Archive conversations
