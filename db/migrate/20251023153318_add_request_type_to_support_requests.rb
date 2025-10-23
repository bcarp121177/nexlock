class AddRequestTypeToSupportRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :support_requests, :request_type, :string, default: "general", null: false
    add_check_constraint :support_requests, "request_type IN ('general', 'dispute', 'question')", name: "support_requests_request_type_values"
  end
end
