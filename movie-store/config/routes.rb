Rails.application.routes.draw do
  # Swagger UI
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    # POST /api/subscriptions       - Provisionally start a subscription after client-side purchase
    # GET  /api/subscriptions/:id    - Get user's subscriptions (user_id as :id)
    resources :subscriptions, only: [:create]
    get "subscriptions/:user_id", to: "subscriptions#show", as: :subscription

    # POST /api/webhooks/apple       - Receive Apple Server Notifications
    post "webhooks/apple", to: "webhooks#apple"
  end
end
