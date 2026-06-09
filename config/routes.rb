Rails.application.routes.draw do
  # Authentication
  resource :session, only: %i[new create show destroy] do
    scope module: :sessions do
      resource :code, only: %i[new create]
    end
  end

  # Logs (?date=YYYY-MM-DD for a specific day or month anchor)
  resource :daylog, only: :show, controller: 'daylogs'
  resource :monthlylog, only: :show, controller: 'monthlylogs'

  # Bullet
  scope 'bullets', module: :bullets do
    resource :pin
    resource :archive,  only: %i[create destroy]
    resource :collect,  only: %i[new create destroy]
    resource :pop,      only: %i[new create destroy]
    resource :export,   only: :show
  end
  concern :completable do
    scope module: :bullets do
      resource :complete, only: %i[create destroy]
    end
  end

  resources :bullets, except: :index, concerns: %i[completable] do
    scope module: :bullets do
      resource :publish, only: :update
    end
  end

  resource :search, only: :show
  resources :buckets, only: %i[index show]
  scope 'buckets', module: :buckets, as: 'buckets' do
    resource :pin, only: %i[create destroy]
  end
  get 'projects/suggestions', to: 'projects/suggestions#index', as: :project_suggestions
  resources :projects
  resources :collections

  # Views
  resources :activities, only: :index
  resources :pinned,    only: :index
  resources :archived,  only: :index

  # Publishing
  resources :published, param: :code

  # Progressive Web App (manifest + scaffolded worker from app/views/pwa/*)
  get 'manifest', to: 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker', to: 'rails/pwa#service_worker', as: :pwa_service_worker

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  namespace :active_storage do
    get 'blobs/:signed_id/inline', to: 'inline_blobs#show', as: :inline_blob
  end

  root 'daylogs#show'
end
