Rails.application.routes.draw do
  # Authentication
  resource :session, only: %i[new create show destroy] do
    scope module: :sessions do
      resource :code, only: %i[new create]
    end
  end

  # Logs
  resource :daylog, only: :show, controller: "daylogs"
  get "daylog/:year/:month/:day", to: "daylogs#show", as: :daylog_on

  resource :monthlylog, only: :show, controller: "monthlylogs"
  get "monthlylog/:year/:month", to: "monthlylogs#show", as: :monthlylog_on

  # Bullet
  scope "bullets", module: :bullets do
    resource :pin,     only: %i[create destroy]
    resource :archive,  only: %i[create destroy]
    resource :collect,  only: %i[new create destroy]
    resource :pop,      only: %i[new create destroy]
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
  resource :buckets do
    scope module: :buckets do
      resource :picker, only: :show
      resource :picker_choice, only: :create
      resource :pin, only: %i[create destroy]
    end
  end
  get "projects/suggestions", to: "projects/suggestions#index", as: :project_suggestions
  resources :projects
  resources :collections

  # Views
  resource  :history, only: :show
  resources :activities, only: :index
  resource  :calendar,  only: :show
  resources :pinned,    only: :index
  resources :archived,  only: :index

  # Publishing
  resources :published, param: :code

  # Progressive Web App (manifest + scaffolded worker from app/views/pwa/*)
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  root "daylogs#show"
end
