class AddRefundedAtToEscrows < ActiveRecord::Migration[8.1]
  def change
    add_column :escrows, :refunded_at, :datetime
  end
end
