class SupportMessage < ApplicationRecord
  belongs_to :support_request
  belongs_to :author, polymorphic: true, optional: true

  has_many_attached :files

  enum :sent_via, {
    web: "web",
    email: "email"
  }, suffix: true

  validates :body, presence: true
  validates :sent_via, presence: true

  scope :ordered, -> { order(created_at: :asc) }
  scope :from_user, -> { where(author_type: "User") }
  scope :from_admin, -> { where(author_type: "User").joins(:author).merge(User.where(admin: true)) }

  after_create :mark_request_as_responded, if: :admin_message?
  after_create :notify_recipient

  def admin_message?
    author.is_a?(User) && author.admin?
  end

  def user_message?
    author.is_a?(User) && !author.admin?
  end

  def anonymous_message?
    author.nil?
  end

  def author_name
    return "Support Team" if admin_message?
    return author.name if author.present?
    support_request.contact_email
  end

  private

  def mark_request_as_responded
    support_request.update(status: "responded") if support_request.open_status?
  end

  def notify_recipient
    # Notify user if admin replied
    if admin_message? && support_request.contact_email.present?
      SupportRequestMailer.new_message_notification(support_request, self).deliver_later
    end

    # Notify admins if user/anonymous replied
    if !admin_message?
      admin_emails = User.where(admin: true).pluck(:email)
      admin_emails.each do |admin_email|
        SupportRequestMailer.admin_reply_notification(admin_email, support_request, self).deliver_later
      end
    end
  end
end
