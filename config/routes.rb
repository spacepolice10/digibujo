# frozen_string_literal: true

Rails.application.routes.draw do
  # --- System ---
  get 'up', to: 'rails/health#show', as: :rails_health_check
  get 'manifest', to: 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker', to: 'rails/pwa#service_worker', as: :pwa_service_worker

  root 'timelines#show'

  # --- Authentication ---
  resource :authentication, only: %i[new create destroy], controller: 'authentication' do
    scope module: :authentications do
      resource :confirmation, only: %i[new create]
    end
  end

  resource :onboarding, only: %i[new create], controller: 'onboarding'
  resource :features, only: :show, controller: 'features'
  resource :support, only: :show, controller: 'support'

  # --- Timeline ---
  resource :timeline, only: :show do
    scope module: :timelines do
      resources :bullets, only: :index
    end
  end
  resource :upcoming, only: :show, controller: 'upcoming'

  # --- Tags ---
  scope module: :projects, path: 'projects', as: :project do
    resources :suggestions
  end
  resources :projects

  # --- Bullets ---
  scope 'bullets', module: :bullets do
    resource :postpone, only: %i[new create]
    resource :archive
    resource :collect, only: %i[new create]
    resource :completion, only: %i[create destroy]
    resource :publish
  end

  resources :bullets, except: :new

  # --- Collections ---
  resources :collections do
    scope module: :collections do
      resource :export
      resources :bullets, only: :index
    end
  end

  # --- Home & navigation ---
  resource :home, controller: 'home'

  scope module: :home do
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

  resources :activities
  resources :archived

  # --- Attachments ---
  resources :attachments, only: %i[index show], param: :signed_id

  # --- Publishing ---
  resources :published, param: :code
end
