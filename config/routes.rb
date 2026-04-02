# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  if Rails.env.development?
    mount Sidekiq::Web => '/sidekiq'
  elsif Rails.env.production?
    sidekiq_username = ENV['SIDEKIQ_USERNAME'].to_s
    sidekiq_password = ENV['SIDEKIQ_PASSWORD'].to_s

    if sidekiq_username.present? && sidekiq_password.present?
      Sidekiq::Web.use Rack::Auth::Basic do |username, password|
        username_match = ActiveSupport::SecurityUtils.secure_compare(
          ::Digest::SHA256.hexdigest(username),
          ::Digest::SHA256.hexdigest(sidekiq_username)
        )
        password_match = ActiveSupport::SecurityUtils.secure_compare(
          ::Digest::SHA256.hexdigest(password),
          ::Digest::SHA256.hexdigest(sidekiq_password)
        )

        username_match && password_match
      end

      mount Sidekiq::Web => '/sidekiq'
    end
  else
    constraints lambda { |request|
      user = User.find_by(id: request.session[:user_id])
      user&.admin?
    } do
      mount Sidekiq::Web => '/sidekiq'
    end
  end

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
  get 'member/order_tasks', to: 'member_order_tasks#index', as: :member_order_tasks
  resource :telegram_connection, only: :show do
    get :status, on: :collection
  end
  get 'telegram/change', to: 'telegram_connections#change', as: :change_telegram_connection
  resource :telegram_subscription, only: :create
  post 'telegram/webhook', to: 'telegram_webhooks#create', as: :telegram_webhook

  namespace :admin do
    resources :markdown_attachments, only: :create
    resources :markdown_images, only: %i[index create]
    get 'work_tracking', to: 'work_tracking#index', as: :work_tracking
    resources :order_services, only: %i[new create show edit update destroy] do
      delete :bulk_destroy, on: :collection
      get :service_options, on: :collection
      resources :order_tasks, only: :update
    end

    resources :members, except: %i[show new edit] do
      patch :reset_password, on: :member
    end

    resource :settings, only: %i[show update]
    post 'settings/sync_google_sheets', to: 'settings#sync_google_sheets', as: :settings_sync_google_sheets
    post 'settings/cancel_google_sheets_sync', to: 'settings#cancel_google_sheets_sync', as: :settings_cancel_google_sheets_sync
    get 'settings/google_sheets_sync_status', to: 'settings#google_sheets_sync_status', as: :settings_google_sheets_sync_status

    resources :services, controller: 'all_services', only: %i[index create update destroy] do
      get :tasks_panel, on: :member
    end

    resources :partners do
      resources :services, only: %i[index create update destroy] do
        get :tasks_panel, on: :member
        resources :tasks, only: %i[index new create update destroy]
      end
    end
  end

  root 'home#index'
end
