resources :support_requests, only: [:index, :new, :create, :show] do
  member do
    post :reply
    post :close
  end
end
