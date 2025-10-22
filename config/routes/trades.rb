resources :trades, only: [:index, :new, :create, :show] do
  member do
    post :attach_media
    post :send_to_buyer
    post :agree
    post :send_for_signature
    post :cancel_signature_request
    post :retry_signature
    get :signing_url
    post :fund
    post :ship
    post :mark_delivered
    post :confirm_receipt
    post :accept
    post :reject
  end

  resources :trade_documents, only: [:index, :show] do
    member do
      get :download
    end
  end
end
