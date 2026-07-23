# frozen_string_literal: true

Rails.application.routes.draw do
  # --- System ---
  get 'up', to: 'rails/health#show', as: :rails_health_check
  get 'manifest', to: 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker', to: 'rails/pwa#service_worker', as: :pwa_service_worker

  root 'home#show'

  # --- Authentication ---
  resource :authentication, only: %i[new create destroy], controller: 'authentication' do
    scope module: :authentications do
      resource :confirmation, only: %i[new create]
    end
  end

  resource :onboarding, only: %i[new create], controller: 'onboarding'
  resource :features, only: :show, controller: 'features'
  resource :support, only: :show, controller: 'support'

  # --- Logs ---
  resource :daylog, only: %i[show create], controller: 'daylogs' do
    resource :mood_entity, only: %i[create destroy], module: :daylogs
    resource :picture, only: %i[create destroy], module: :daylogs
  end

  get 'monthlylog', to: 'monthlylogs#show', as: :current_monthlylog
  get 'monthly_bucket', to: redirect('/monthlylog')

  get 'future', to: 'futures#show', as: :current_future

  resources :futures, only: %i[show new create]

  resources :monthlylogs, only: %i[new create show] do
    resources :trackers, only: %i[new create], module: :monthlylogs
  end

  get 'future_buckets/:id', to: redirect('/futures/%{id}')
  get 'monthly_buckets/:id', to: redirect('/monthlylogs/%{id}')

  # --- Tags ---
  scope 'projects', module: :projects, as: :projects do
    resource :pin, only: %i[create destroy]
  end
  scope module: :projects, path: 'projects', as: :project do
    resources :suggestions
  end
  resources :projects

  # --- Bullets ---
  scope 'bullets', module: :bullets do
    resource :pin
    resource :postpone, only: %i[new create]
    resource :archive
    resource :collect, only: %i[new create]
    resource :publish
    resource :mark_as_reviewed
  end

  resources :bullets, except: :index

  # --- Tasks ---
  scope 'tasks', module: :tasks do
    resource :complete
  end

  # --- Buckets & collections ---
  resources :collections do
    scope module: :collections do
      resource :export
    end
  end

  scope 'buckets', module: :buckets, as: :buckets do
    resource :pin
  end
  resources :buckets, only: :show

  # --- Trackers ---
  resources :trackers, only: %i[show edit update destroy] do
    scope module: :trackers do
      resource :completion
    end
  end

  # --- Home & navigation ---
  resource :home, controller: 'home' do
    resources :activities, module: :home
  end

  scope module: :home do
    post 'home/sections/:id/expand', to: 'sections#expand', as: :home_expand_section
    post 'home/sections/:id/collapse', to: 'sections#collapse', as: :home_collapse_section
    post 'home/appearance', to: 'appearances#update', as: :home_appearance
  end

  resource :user, only: :show

  resource :menu, controller: 'menu'
  resource :search do
    scope module: :searches do
      resource :selection, only: :create
    end
  end

  # --- Workspaces ---
  resource :review, controller: 'reviews' do
    scope module: :reviews do
      resources :collections, only: :index
      resource :scheduled, only: :show, controller: 'scheduled'
    end
  end
  resources :activities
  resources :pinned
  resources :archived

  # --- Attachments ---
  resources :attachments, only: :show, param: :signed_id

  # --- Publishing ---
  resources :published, param: :code
end
