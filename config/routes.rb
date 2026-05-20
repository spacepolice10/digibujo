Rails.application.routes.draw do
  # Authentication
  resource :session, only: %i[new create show destroy] do
    scope module: :sessions do
      resource :code, only: %i[new create]
    end
  end

  # Bullet
  scope 'bullets', module: :bullets do
    resources :fields, only: :show
    resources :contexts, only: :index
  end
  concern :completable do
    scope module: :bullets do
      resource :complete, only: %i[create destroy]
    end
  end

  resources :bullets, concerns: %i[completable] do
    scope module: :bullets do
      resource :pin,             only: :update
      resource :archive,         only: :update
      resource :postpone,        only: :create
      resource :collect,         only: :create
      resource :schedule,        only: :create
      resource :publish,         only: :update
    end
  end

  resource :search, only: :show

  resource :buckets
  resources :projects
  resources :collections

  # Views
  resource  :monthly_log, only: :show
  resource  :history, only: :show
  resources :activities, only: :index
  resource  :calendar,  only: :show
  resources :pinned,    only: :index
  resources :archived,  only: :index

  # Publishing
  resources :published, param: :code

  # Progressive Web App (manifest + scaffolded worker from app/views/pwa/*)
  get 'manifest', to: 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker', to: 'rails/pwa#service_worker', as: :pwa_service_worker

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'bullets#index'
end
