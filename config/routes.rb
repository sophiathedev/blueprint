# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  get 'login', to: 'users#login', as: :login
  post 'login', to: 'users#perform_sign_in'
  delete 'logout', to: 'users#logout', as: :logout
  get 'change-password', to: 'users#change_password', as: :change_password
  patch 'change-password', to: 'users#perform_password_change'

  namespace :admin do
    resources :partners
  end

  root 'home#index'
end
