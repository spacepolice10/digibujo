# frozen_string_literal: true

Rails.application.routes.draw do
  # --- System ---
  get 'up', to: 'rails/health#show', as: :rails_health_check
  get 'manifest', to: 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker', to: 'rails/pwa#service_worker', as: :pwa_service_worker

  root 'daylogs#show'

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
    scope module: :daylogs do
      resources :bullets, only: :index
      resource :metadata, only: :show
    end
  end

  scope 'calendar_date', module: :calendar_dates, as: :calendar_date do
    resource :mood_entity, only: %i[create]
    resource :picture, only: %i[create destroy]
  end

  resource :triage, only: :show, controller: 'triage' do
    scope module: :triage do
      resources :bullets, only: [] do
        resource :accept, only: :create
        resource :discard, only: :create
        resource :postpone, only: :create
      end
    end
  end

  get 'triage/number', to: 'triage#number', as: :triage_number

  get 'monthlylog', to: 'monthlylogs#show', as: :current_monthlylog

  get 'future', to: 'futures#show', as: :current_future

  resources :futures, only: %i[show new create] do
    scope module: :futures do
      resources :bullets, only: :index
    end
  end

  resources :monthlylogs, only: %i[create show] do
    scope module: :monthlylogs do
      resources :bullets, only: :index
    end
  end

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
  end

  resources :bullets, except: %i[index new]

  # --- Tasks ---
  scope 'tasks', module: :tasks do
    resource :complete
  end

  # --- Buckets & collections ---
  resources :collections do
    scope module: :collections do
      resource :export
      resources :bullets, only: :index
    end
  end

  scope 'buckets', module: :buckets, as: :buckets do
    resource :pin
  end
  resources :buckets, only: :show

  # --- Trackers ---
  resources :trackers do
    scope module: :trackers do
      resource :status
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

  resources :access_codes, only: %i[index create destroy]
  resources :hooks, only: %i[index new create destroy]
  post 'hooks/:code', to: 'hook_intakes#create', as: :hook_intake, constraints: { code: /hk_[A-Za-z0-9]+/ }

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
