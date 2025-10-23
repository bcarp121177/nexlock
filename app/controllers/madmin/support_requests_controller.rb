module Madmin
  class SupportRequestsController < Madmin::ResourceController
    before_action :set_support_request, only: [:reply, :close, :reopen]

    # Override index to add status filter
    def index
      @status_filter = params[:status]

      scope = SupportRequest.includes(:account, :trade, :opened_by).ordered
      scope = scope.by_status(@status_filter) if @status_filter.present?

      @pagy, @records = pagy(scope, limit: 20)
    end

    # Override show to include messages
    def show
      @support_request = SupportRequest.includes(
        :account,
        :trade,
        :opened_by,
        :closed_by,
        support_messages: [:author, { files_attachments: :blob }]
      ).find(params[:id])

      @messages = @support_request.support_messages.ordered
      @new_message = @support_request.support_messages.build
    end

    # POST /madmin/support_requests/:id/reply
    def reply
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

        redirect_to "/admin/support_requests/#{@support_request.id}", notice: "Reply sent."
      else
        redirect_to "/admin/support_requests/#{@support_request.id}", alert: "Failed to send reply: #{@message.errors.full_messages.join(', ')}"
      end
    end

    # POST /madmin/support_requests/:id/close
    def close
      if @support_request.close!(current_user)
        # Send closed notification
        if @support_request.contact_email.present?
          SupportRequestMailer.request_closed_notification(@support_request).deliver_later
        end

        redirect_to "/admin/support_requests/#{@support_request.id}", notice: "Support request closed."
      else
        redirect_to "/admin/support_requests/#{@support_request.id}", alert: "Unable to close request."
      end
    end

    # POST /madmin/support_requests/:id/reopen
    def reopen
      if @support_request.reopen!
        redirect_to "/admin/support_requests/#{@support_request.id}", notice: "Support request reopened."
      else
        redirect_to "/admin/support_requests/#{@support_request.id}", alert: "Unable to reopen request."
      end
    end

    private

    def set_support_request
      @support_request = SupportRequest.find(params[:id])
    end
  end
end
