class AddStripeCheckoutSessionIdToEscrows < ActiveRecord::Migration[8.1]
  def change
    add_column :escrows, :stripe_checkout_session_id, :string
  end
end
