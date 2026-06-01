Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :transcripts, only: [ :index, :new, :create, :show ]
  resource :search, only: [ :show ], controller: "searches"

  resources :questions, only: [ :index, :new, :create, :show ] do
    resource :answer, only: [ :show ], controller: "answers"
  end
  resources :themes, only: [ :index, :create ]

  namespace :api do
    namespace :v1 do
      get  "search",  to: "search#index"
      post "quotes",  to: "search#quotes"
      get  "themes",  to: "themes#index"
      post "themes",  to: "themes#create"
      post "ask",     to: "questions#ask"
    end
  end

  root "transcripts#index"
end
