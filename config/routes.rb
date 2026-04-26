Rails.application.routes.draw do
  # Authentication
  resource :session, only: %i[new create show destroy] do
    scope module: :sessions do
      resource :code, only: %i[new create]
    end
  end

  # Card
  scope 'cards', module: :cards do
    resources :fields, only: :show
    get "contexts", to: "contexts#index", defaults: { format: :json }
  end
  resources :cards do
    scope module: :cards do
      resource :pop,             only: :update
      resource :pin,             only: :update
      resource :archive,         only: :update
      resource :complete,        only: %i[create destroy]
      resource :publish,         only: :update
      resource :playlist_picker, only: :show
    end
  end

  get "todays", to: "cards#index", as: :todays
  resource :search, only: :show

  # Triage
  resource :triage, only: :show, controller: :triage do
    scope module: :triage do
      resources :cards, only: [], param: :card_id do
        resource :collect,  only: :create, controller: :collects
        resource :postpone, only: :create, controller: :postpones
        resource :schedule, only: :create, controller: :schedules
        resource :archive,  only: :create, controller: :archives
      end
    end
  end
  resources :playlists, only: %i[index show create destroy] do
    scope module: :playlists do
      resources :cards, only: %i[create destroy]
      resource :reorder, only: :update
    end
  end

  # Organization & filtering
  get "indexing", to: "streams#index", as: :indexing
  get "collections", to: "collections#index", defaults: { format: :json }
  resources :collections, only: %i[show destroy]
  resources :streams

  # Views
  resource  :history,   only: :show
  resource  :calendar,  only: :show
  resources :pinned,    only: :index
  resources :archived,  only: :index

  # Publishing
  resources :published, param: :code

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  root "cards#index"
end
