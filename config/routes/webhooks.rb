scope :webhooks, module: :webhooks do
  post :stripe, to: "stripe#create"
  post :docuseal, to: "docuseal#create"
end
