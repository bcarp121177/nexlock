class ApplicationMailbox < ActionMailbox::Base
  # Route all emails to support@* addresses to the support mailbox
  routing /support@/i => :support
end
