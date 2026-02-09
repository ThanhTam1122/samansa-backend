require "swagger_helper"

RSpec.describe "Api::Webhooks", type: :request do
  path "/api/webhooks/apple" do
    post "Receive Apple Server Notification" do
      tags "Webhooks"
      description "Receives Apple Server-to-Server notifications for subscription lifecycle events (PURCHASE, RENEW, CANCEL). " \
                  "Idempotent: duplicate notification_uuid is safely ignored."
      consumes "application/json"
      produces "application/json"

      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          webhook: {
            type: :object,
            required: %w[notification_uuid type transaction_id product_id purchase_date expires_date],
            properties: {
              notification_uuid: { type: :string, example: "notif_001", description: "Unique notification identifier" },
              type: { type: :string, enum: %w[PURCHASE RENEW CANCEL], description: "Event type" },
              transaction_id: { type: :string, example: "txn_abc", description: "Apple transaction ID" },
              product_id: { type: :string, example: "com.samansa.subscription.monthly", description: "Subscription plan ID" },
              amount: { type: :string, example: "3.9", description: "Charge amount" },
              currency: { type: :string, example: "USD", description: "Currency code" },
              purchase_date: { type: :string, format: "date-time", example: "2025-10-01T12:00:00Z", description: "Period start date" },
              expires_date: { type: :string, format: "date-time", example: "2025-11-01T12:00:00Z", description: "Period end / next renewal date" }
            }
          }
        },
        required: %w[webhook]
      }

      response "200", "Webhook processed — PURCHASE activates subscription" do
        schema type: :object, properties: {
          status: { type: :string, example: "processed" }
        }

        before do
          Subscription.create!(user_id: "user_123", transaction_id: "txn_purchase", product_id: "com.samansa.subscription.monthly", status: "pending")
        end

        let(:params) do
          {
            webhook: {
              notification_uuid: "notif_purchase_001",
              type: "PURCHASE",
              transaction_id: "txn_purchase",
              product_id: "com.samansa.subscription.monthly",
              amount: "3.9",
              currency: "USD",
              purchase_date: "2025-10-01T12:00:00Z",
              expires_date: "2025-11-01T12:00:00Z"
            }
          }
        end
        run_test!
      end

      response "200", "Webhook processed — RENEW extends subscription" do
        schema type: :object, properties: {
          status: { type: :string, example: "processed" }
        }

        before do
          Subscription.create!(user_id: "user_123", transaction_id: "txn_renew", product_id: "com.samansa.subscription.monthly",
                               status: "active", purchase_date: "2025-10-01T12:00:00Z", expires_date: "2025-11-01T12:00:00Z")
        end

        let(:params) do
          {
            webhook: {
              notification_uuid: "notif_renew_001",
              type: "RENEW",
              transaction_id: "txn_renew",
              product_id: "com.samansa.subscription.monthly",
              amount: "3.9",
              currency: "USD",
              purchase_date: "2025-11-01T12:00:00Z",
              expires_date: "2025-12-01T12:00:00Z"
            }
          }
        end
        run_test!
      end

      response "200", "Webhook processed — CANCEL marks subscription as cancelled" do
        schema type: :object, properties: {
          status: { type: :string, example: "processed" }
        }

        before do
          Subscription.create!(user_id: "user_123", transaction_id: "txn_cancel", product_id: "com.samansa.subscription.monthly",
                               status: "active", purchase_date: "2025-10-01T12:00:00Z", expires_date: "2025-11-01T12:00:00Z")
        end

        let(:params) do
          {
            webhook: {
              notification_uuid: "notif_cancel_001",
              type: "CANCEL",
              transaction_id: "txn_cancel",
              product_id: "com.samansa.subscription.monthly",
              amount: "3.9",
              currency: "USD",
              purchase_date: "2025-10-01T12:00:00Z",
              expires_date: "2025-11-01T12:00:00Z"
            }
          }
        end
        run_test!
      end

      response "200", "Duplicate notification ignored (idempotent)" do
        schema type: :object, properties: {
          status: { type: :string, example: "already_processed" }
        }

        before do
          sub = Subscription.create!(user_id: "user_123", transaction_id: "txn_idem", product_id: "com.samansa.subscription.monthly", status: "active",
                                     purchase_date: "2025-10-01T12:00:00Z", expires_date: "2025-11-01T12:00:00Z")
          SubscriptionEvent.create!(notification_uuid: "notif_dup_001", transaction_id: "txn_idem", event_type: "PURCHASE",
                                    product_id: "com.samansa.subscription.monthly", processed_at: Time.current)
        end

        let(:params) do
          {
            webhook: {
              notification_uuid: "notif_dup_001",
              type: "PURCHASE",
              transaction_id: "txn_idem",
              product_id: "com.samansa.subscription.monthly",
              amount: "3.9",
              currency: "USD",
              purchase_date: "2025-10-01T12:00:00Z",
              expires_date: "2025-11-01T12:00:00Z"
            }
          }
        end
        run_test!
      end

      response "404", "Subscription not found for transaction_id" do
        schema type: :object, properties: {
          error: { type: :string }
        }

        let(:params) do
          {
            webhook: {
              notification_uuid: "notif_missing_001",
              type: "PURCHASE",
              transaction_id: "txn_nonexistent",
              product_id: "com.samansa.subscription.monthly",
              amount: "3.9",
              currency: "USD",
              purchase_date: "2025-10-01T12:00:00Z",
              expires_date: "2025-11-01T12:00:00Z"
            }
          }
        end
        run_test!
      end
    end
  end
end
