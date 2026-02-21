Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :cards do
    scope module: :cards do
      resource :stash, only: :update
      resource :pin, only: :update
      resource :archive, only: :update
      resource :completion, only: [ :create, :destroy ]
    end
  end
  resources :streams
  resources :tags
  resources :stashed, only: :index

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "streams#index"
end
