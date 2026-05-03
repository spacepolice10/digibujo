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
    get "contexts", to: "contexts#index", defaults: { format: :json }
  end
  resources :bullets do
    scope module: :bullets do
      resource :pin,             only: :update
      resource :archive,         only: :update
      resource :complete,        only: %i[create destroy]
      resource :publish,         only: :update
      resource :playlist_picker, only: :show
    end
  end

  resource :search, only: :show

  # Triage (`resources :bullets` under `/triage` encodes `:bullet_id` as `:bullet_bullet_id`; use explicit paths)
  get "triage", to: "triage#show", as: :triage

  scope module: :triage do
    post "triage/bullets/:bullet_id/collect",  to: "collects#create",  as: :triage_bullet_collect
    post "triage/bullets/:bullet_id/postpone", to: "postpones#create", as: :triage_bullet_postpone
    post "triage/bullets/:bullet_id/schedule", to: "schedules#create", as: :triage_bullet_schedule
    post "triage/bullets/:bullet_id/archive",  to: "archives#create",  as: :triage_bullet_archive
  end
  resources :playlists, only: %i[index show create destroy] do
    scope module: :playlists do
      resources :bullets, only: %i[create destroy]
      resource :reorder, only: :update
    end
  end

  # Organization & filtering
  get "indexing", to: "streams#index", as: :indexing
  get "projects", to: "projects#index", defaults: { format: :json }
  resources :projects, only: %i[show destroy]
  resources :streams

  # Views
  resource  :history,   only: :show
  resource  :calendar,  only: :show
  resources :pinned,    only: :index
  resources :archived,  only: :index

  # Publishing
  resources :published, param: :code

  # Progressive Web App (manifest + scaffolded worker from app/views/pwa/*)
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  root "bullets#index"
end
