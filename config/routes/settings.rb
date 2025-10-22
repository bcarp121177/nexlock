resource :settings, only: [:show] do
  post :start_stripe_onboarding
end
