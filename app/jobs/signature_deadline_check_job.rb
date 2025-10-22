class SignatureDeadlineCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Running signature deadline check..."

    result = TradeDocumentService.check_signature_deadlines

    if result[:expired_count] > 0
      Rails.logger.info "Expired #{result[:expired_count]} signature request(s)"
    else
      Rails.logger.info "No expired signature requests found"
    end
  end
end
