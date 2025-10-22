resources :trades, only: [:index, :new, :create, :show] do
  member do
    post :attach_media
    post :send_to_buyer
    post :agree
    post :ship
    post :mark_delivered
    post :confirm_receipt
    post :accept
    post :reject
  end
end
