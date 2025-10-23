class SupportRequestsController < ApplicationController
  before_action :authenticate_user!, except: [:new, :create]
  before_action :set_support_request, only: [:show, :reply, :close]

  # GET /support_requests
  def index
    # Ensure user has a current account
    unless current_account
      redirect_to accounts_path, alert: "Please select an account to continue."
      return
    end

    @pagy, @support_requests = pagy(
      current_account.support_requests.includes(:trade).ordered,
      limit: 20
    )
  end

  # GET /support_requests/:id
  def show
    authorize_request_access!
    @messages = @support_request.support_messages.includes(:author).ordered
    @new_message = @support_request.support_messages.build
  end

  # GET /support_requests/new
  def new
    @support_request = SupportRequest.new
    @trade = Trade.find(params[:trade_id]) if params[:trade_id].present?
  end

  # POST /support_requests
  def create
    @support_request = SupportRequest.new(support_request_params)

    # Set account and user if signed in
    if user_signed_in?
      @support_request.account = current_account
      @support_request.opened_by = current_user
      @support_request.email = nil # Don't need email if user is signed in
    end

    # Create the initial message
    initial_body = params[:description] || params[:body]

    if @support_request.save
      # Create first message
      message = @support_request.support_messages.create!(
        body: initial_body,
        author: current_user,
        sent_via: "web"
      )

      # Attach files if any
      if params[:files].present?
        message.files.attach(params[:files])
      end

      # Send notification to admins
      admin_emails = User.where(admin: true).pluck(:email)
      admin_emails.each do |email|
        SupportRequestMailer.new_request_notification(email, @support_request).deliver_later
      end

      if user_signed_in?
        redirect_to support_request_path(@support_request), notice: "Support request submitted successfully."
      else
        redirect_to root_path, notice: "Support request submitted. We'll reply to #{@support_request.email} soon."
      end
    else
      @trade = @support_request.trade
      render :new, status: :unprocessable_content
    end
  end

  # POST /support_requests/:id/reply
  def reply
    authorize_request_access!

    @message = @support_request.support_messages.build(
      body: params[:body],
      author: current_user,
      sent_via: "web"
    )

    if @message.save
      # Attach files if any
      if params[:files].present?
        @message.files.attach(params[:files])
      end

      redirect_to support_request_path(@support_request), notice: "Reply sent."
    else
      @messages = @support_request.support_messages.includes(:author).ordered
      @new_message = @message
      render :show, status: :unprocessable_content
    end
  end

  # POST /support_requests/:id/close
  def close
    authorize_request_access!

    if @support_request.close!(current_user)
      redirect_to support_request_path(@support_request), notice: "Support request closed."
    else
      redirect_to support_request_path(@support_request), alert: "Unable to close request."
    end
  end

  private

  def set_support_request
    @support_request = SupportRequest.find(params[:id])
  end

  def authorize_request_access!
    # Allow if user is admin
    return if current_user&.admin?

    # Allow if user opened the request
    return if @support_request.opened_by == current_user

    # Allow if request belongs to user's account
    return if current_account && @support_request.account_id == current_account.id

    redirect_to root_path, alert: "Access denied."
  end

  def support_request_params
    params.require(:support_request).permit(:subject, :email, :trade_id)
  end
end
