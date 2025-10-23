class SupportMailbox < ApplicationMailbox
  # Handles inbound emails to support@* addresses
  # Routes them to support requests based on In-Reply-To header or creates new requests

  before_processing :find_or_create_support_request

  def process
    # Create a new message in the support request thread
    message = @support_request.support_messages.create!(
      body: extract_body,
      author: find_author,
      sent_via: "email",
      message_id: mail.message_id
    )

    # Attach any files from the email
    mail.attachments.each do |attachment|
      message.files.attach(
        io: StringIO.new(attachment.body.to_s),
        filename: attachment.filename,
        content_type: attachment.content_type
      )
    end
  end

  private

  def find_or_create_support_request
    # Try to find existing request via In-Reply-To header (email threading)
    if mail.in_reply_to.present?
      existing_message = SupportMessage.find_by(message_id: mail.in_reply_to)
      @support_request = existing_message&.support_request
    end

    # If no existing request found, create a new one
    @support_request ||= create_new_support_request

    # Bounce the email if we couldn't create/find a request
    unless @support_request
      bounced!
    end
  end

  def create_new_support_request
    # Extract subject and sender
    subject = mail.subject.presence || "Support Request"
    from_email = mail.from.first

    # Try to find user by email
    user = User.find_by(email: from_email)

    # Create the support request
    SupportRequest.create!(
      subject: subject,
      email: user.nil? ? from_email : nil,
      opened_by: user,
      account: user&.personal_account,
      status: "open"
    )
  end

  def find_author
    # Try to find user by email address
    User.find_by(email: mail.from.first)
  end

  def extract_body
    # Prefer plain text, fall back to HTML
    if mail.text_part
      mail.text_part.decoded
    elsif mail.html_part
      strip_html(mail.html_part.decoded)
    else
      mail.decoded
    end
  end

  def strip_html(html)
    # Simple HTML stripping - you might want to use a gem like Sanitize for production
    html.gsub(/<[^>]*>/, "").strip
  end
end
