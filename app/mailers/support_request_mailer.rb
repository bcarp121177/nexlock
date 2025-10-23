class SupportRequestMailer < ApplicationMailer
  # Notify admin of new support request
  def new_request_notification(admin_email, support_request)
    @support_request = support_request
    @initial_message = support_request.support_messages.first

    mail(
      to: admin_email,
      subject: "[Support] New Request: #{support_request.subject}",
      message_id: "<support-request-#{support_request.id}@#{ActionMailer::Base.default_url_options[:host]}>",
      from: "support@#{ActionMailer::Base.default_url_options[:host]}"
    )
  end

  # Notify user of admin reply
  def new_message_notification(support_request, message)
    @support_request = support_request
    @message = message

    mail(
      to: support_request.contact_email,
      subject: "Re: #{support_request.subject}",
      in_reply_to: "<support-request-#{support_request.id}@#{ActionMailer::Base.default_url_options[:host]}>",
      message_id: "<support-message-#{message.id}@#{ActionMailer::Base.default_url_options[:host]}>",
      from: "support@#{ActionMailer::Base.default_url_options[:host]}"
    )
  end

  # Notify admin of user reply
  def admin_reply_notification(admin_email, support_request, message)
    @support_request = support_request
    @message = message

    mail(
      to: admin_email,
      subject: "[Support] Reply to: #{support_request.subject}",
      in_reply_to: "<support-request-#{support_request.id}@#{ActionMailer::Base.default_url_options[:host]}>",
      message_id: "<support-message-#{message.id}-admin@#{ActionMailer::Base.default_url_options[:host]}>",
      from: "support@#{ActionMailer::Base.default_url_options[:host]}"
    )
  end

  # Notify user that their request is closed
  def request_closed_notification(support_request)
    @support_request = support_request

    mail(
      to: support_request.contact_email,
      subject: "Closed: #{support_request.subject}",
      in_reply_to: "<support-request-#{support_request.id}@#{ActionMailer::Base.default_url_options[:host]}>",
      from: "support@#{ActionMailer::Base.default_url_options[:host]}"
    )
  end
end
