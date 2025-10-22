scope :webhooks, module: :webhooks do
  post :stripe, to: "stripe#create"
end
