Rails.application.routes.draw do
  resource :session, only: %i[new create destroy] do
    scope module: :sessions do
      resource :code, only: %i[new create]
    end
  end
  scope 'cards', module: :cards do
    resources :fields, only: :show
  end
  resources :cards do
    scope module: :cards do
      resource :pop,           only: :update
      resource :pin,           only: :update
      resource :archive,       only: :update
      resource :complete, only: %i[create destroy]
    end
  end
  resources :drafts, only: [:index] do
    scope module: :drafts do
      resource :schedule, only: :create
      resource :collect,  only: :create
      resource :postpone, only: :create
      resource :remove,   only: :create
    end
  end
  resources :tags
  resources :streams
  resource :calendar, only: :show
  resources :pinned,    only: :index
  resources :archived,  only: :index

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'home#index'
end
