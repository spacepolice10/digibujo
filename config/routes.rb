# frozen_string_literal: true

Rails.application.routes.draw do
  # Authentication
  resource :session, only: %i[new create show destroy] do
    scope module: :sessions do
      resource :code, only: %i[new create]
    end
  end

  # Logs (?date=YYYY-MM-DD for a specific day)
  resource :daylog, only: :show, controller: 'daylogs'
  get 'monthly_bucket', to: 'monthly_buckets#current', as: :monthly_bucket
  resources :monthly_buckets, only: %i[show new create] do
    scope module: :monthly_buckets do
      resources :bullets, only: %i[new create]
    end
  end
  resources :bundles, only: %i[show new create destroy]

  # Bullet
  scope 'bullets', module: :bullets do
    resource :pin
    resource :archive,  only: %i[create destroy]
    resource :collect,  only: %i[new create destroy]
    resource :pop,      only: %i[new create destroy]
    resource :complete, only: %i[create destroy]
    resource :export,   only: :show
  end
  resources :bullets, except: :index do
    scope module: :bullets do
      resource :publish, only: :update
    end
  end

  resource :search, only: :show
  resource :menu, only: :show, controller: 'menu'
  resources :notes, only: :index
  resources :buckets, only: :show
  resource :home, only: :show, controller: 'home'
  scope module: :home do
    post 'home/sections/:id/expand',   to: 'sections#expand',   as: :home_expand_section
    post 'home/sections/:id/collapse', to: 'sections#collapse', as: :home_collapse_section
  end
  resource :future, only: %i[show create], controller: 'futures' do
    post :months, on: :collection
  end
  scope 'buckets', module: :buckets, as: 'buckets' do
    resource :pin, only: %i[create destroy]
  end
  get 'projects/suggestions', to: 'projects/suggestions#index', as: :project_suggestions
  scope 'projects', module: :projects, as: 'projects' do
    resource :pin, only: %i[create destroy]
  end
  resources :projects
  resources :collections
  get 'people/suggestions', to: 'people/suggestions#index', as: :person_suggestions
  scope 'people', module: :people, as: 'people' do
    resource :pin, only: %i[create destroy]
  end
  resources :people, only: %i[index new create show destroy]

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

  root 'daylogs#show'
end
