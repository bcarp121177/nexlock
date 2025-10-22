class DocumentSignature < ApplicationRecord
  belongs_to :account
  belongs_to :trade_document
  belongs_to :user, optional: true

  enum :signer_role, { seller: 0, buyer: 1, witness: 2 }, suffix: true
end
