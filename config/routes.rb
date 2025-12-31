# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  namespace :admin do
    get '/login', to: 'sessions#new', as: :new_session
    post '/login', to: 'sessions#create', as: :sessions
    delete '/logout', to: 'sessions#destroy', as: :logout
  end

  ActiveAdmin.routes(self)

  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'authentication#login'
      post 'auth/refresh', to: 'authentication#refresh'
      post 'auth/logout', to: 'authentication#logout'

      get 'user', to: 'user#index'

      get 'data', to: 'data#index'
      post 'data_backup/init', to: 'data_backup#init'
      post 'data_backup/finalize', to: 'data_backup#finalize'

      # Using post here since we're sending a list of file keys in the
      # request body and so we are not limited by the URL length.
      post 'asset_files/download_urls', to: 'asset_files#download_urls'
      post 'asset_files/upload_url', to: 'asset_files#upload_url'
      put 'asset_files/upload_proxy/:file_key', to: 'asset_files#upload_proxy'
      post 'asset_files/file_info', to: 'asset_files#file_info'
      post 'asset_files/delete_file', to: 'asset_files#delete_file'
    end
  end

  # Defines the root path route ("/")
  root to: 'admin/sessions#new'
end
