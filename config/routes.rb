# frozen_string_literal: true

Rails.application.routes.draw do
  # --- System ---
  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker

  root "daylogs#show"

  # --- Authentication ---
  resource :session do
    scope module: :sessions do
      resource :code, only: %i[new create]
    end
  end

  resource :signup, only: %i[new create] do
    scope module: :signups do
      resource :completion, only: %i[new create]
    end
  end

  # --- Logs ---
  resource :daylog, only: :show, controller: "daylogs"

  get "monthly_bucket", to: "monthly_buckets#current", as: :current_monthly_bucket

  # Plural :futures supports multiple future_buckets later; show/months stay on /future for now.
  get "future", to: "futures#show", as: :future
  post "future/months", to: "futures#months", as: :months_future

  scope path: "future", as: :future do
    resources :monthly_buckets, controller: "monthly_buckets" do
      scope module: :monthly_buckets do
        resources :bullets, only: %i[new create]
      end
    end
  end

  # --- Tags ---
  scope "projects", module: :projects, as: :projects do
    resource :pin, only: %i[create destroy]
  end

  scope module: :projects, path: "projects", as: :project do
    resources :suggestions
  end

  resources :projects

  scope "people", module: :people, as: :people do
    resource :pin, only: %i[create destroy]
  end

  scope module: :people, path: "people", as: :person do
    resources :suggestions
  end

  resources :people

  # --- Bullets ---
  scope "bullets", module: :bullets do
    resource :pin, only: %i[create destroy]
    resource :archive, only: %i[create destroy]
    resource :collect
    resource :pop
    resource :complete, only: %i[create destroy]
    resource :publish, only: %i[create destroy]
    resource :export
  end

  resources :bullets, except: :index

  # --- Buckets & collections ---
  resources :collections

  scope "buckets", module: :buckets, as: :buckets do
    resource :pin, only: %i[create destroy]
  end

  resources :buckets, only: :show

  # --- Recurrencies ---
  resources :recurrencies do
    scope module: :recurrencies do
      resource :completion, only: %i[create destroy]
    end
  end

  # --- Home & navigation ---
  resource :home, controller: "home"

  scope module: :home do
    post "home/sections/:id/expand", to: "sections#expand", as: :home_expand_section
    post "home/sections/:id/collapse", to: "sections#collapse", as: :home_collapse_section
  end

  resource :menu, controller: "menu"
  resource :search do
    scope module: :searches do
      resource :selection, only: :create
    end
  end

  # --- Workspaces ---
  resource :review, controller: "reviews"
  resources :activities
  resources :pinned
  resources :archived

  # --- Publishing ---
  resources :published, param: :code, only: %i[index show]
end
