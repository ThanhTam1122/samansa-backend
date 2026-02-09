require "swagger_helper"

RSpec.describe "Api::Subscriptions", type: :request do
  path "/api/subscriptions" do
    post "Create a subscription (provisional start)" do
      tags "Subscriptions"
      description "Called by the client app after Apple In-App Purchase completes. " \
                  "Creates a subscription in 'pending' state. Idempotent: if transaction_id already exists, returns the existing record."
      consumes "application/json"
      produces "application/json"

      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          subscription: {
            type: :object,
            required: %w[user_id transaction_id product_id],
            properties: {
              user_id: { type: :string, example: "user_123", description: "User identifier" },
              transaction_id: { type: :string, example: "txn_abc", description: "Apple transaction ID (unique per subscription)" },
              product_id: { type: :string, example: "com.samansa.subscription.monthly", description: "Subscription plan ID" }
            }
          }
        },
        required: %w[subscription]
      }

      response "201", "Subscription created (pending)" do
        schema type: :object, properties: {
          id: { type: :integer },
          user_id: { type: :string },
          transaction_id: { type: :string },
          product_id: { type: :string },
          status: { type: :string, enum: %w[pending active cancelled] },
          viewable: { type: :boolean },
          purchase_date: { type: :string, nullable: true, format: "date-time" },
          expires_date: { type: :string, nullable: true, format: "date-time" },
          created_at: { type: :string, format: "date-time" },
          updated_at: { type: :string, format: "date-time" }
        }

        let(:params) { { subscription: { user_id: "user_123", transaction_id: "txn_new", product_id: "com.samansa.subscription.monthly" } } }
        run_test!
      end

      response "200", "Subscription already exists (idempotent)" do
        schema type: :object, properties: {
          id: { type: :integer },
          user_id: { type: :string },
          transaction_id: { type: :string },
          product_id: { type: :string },
          status: { type: :string },
          viewable: { type: :boolean },
          purchase_date: { type: :string, nullable: true, format: "date-time" },
          expires_date: { type: :string, nullable: true, format: "date-time" },
          created_at: { type: :string, format: "date-time" },
          updated_at: { type: :string, format: "date-time" }
        }

        before do
          Subscription.create!(user_id: "user_123", transaction_id: "txn_dup", product_id: "com.samansa.subscription.monthly", status: "pending")
        end

        let(:params) { { subscription: { user_id: "user_123", transaction_id: "txn_dup", product_id: "com.samansa.subscription.monthly" } } }
        run_test!
      end
    end
  end

  path "/api/subscriptions/{user_id}" do
    get "Get subscriptions for a user" do
      tags "Subscriptions"
      description "Returns all subscriptions for a given user, including their viewing eligibility."
      produces "application/json"

      parameter name: :user_id, in: :path, type: :string, description: "User ID", example: "user_123"

      response "200", "User subscriptions retrieved" do
        schema type: :object, properties: {
          user_id: { type: :string },
          subscriptions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                user_id: { type: :string },
                transaction_id: { type: :string },
                product_id: { type: :string },
                status: { type: :string, enum: %w[pending active cancelled] },
                viewable: { type: :boolean },
                purchase_date: { type: :string, nullable: true, format: "date-time" },
                expires_date: { type: :string, nullable: true, format: "date-time" },
                created_at: { type: :string, format: "date-time" },
                updated_at: { type: :string, format: "date-time" }
              }
            }
          }
        }

        before do
          Subscription.create!(user_id: "user_456", transaction_id: "txn_show", product_id: "com.samansa.subscription.monthly", status: "active",
                               purchase_date: "2025-10-01T12:00:00Z", expires_date: "2025-11-01T12:00:00Z")
        end

        let(:user_id) { "user_456" }
        run_test!
      end
    end
  end
end
