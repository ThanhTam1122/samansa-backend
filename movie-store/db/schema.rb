# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_09_000002) do
  create_table "subscription_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "event_type", null: false
    t.datetime "expires_date"
    t.string "notification_uuid", null: false
    t.datetime "processed_at"
    t.string "product_id"
    t.datetime "purchase_date"
    t.string "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_subscription_events_on_event_type"
    t.index ["notification_uuid"], name: "index_subscription_events_on_notification_uuid", unique: true
    t.index ["transaction_id"], name: "index_subscription_events_on_transaction_id"
  end

  create_table "subscriptions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "currency"
    t.datetime "expires_date"
    t.string "product_id", null: false
    t.datetime "purchase_date"
    t.string "status", default: "pending", null: false
    t.string "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["expires_date"], name: "index_subscriptions_on_expires_date"
    t.index ["transaction_id"], name: "index_subscriptions_on_transaction_id", unique: true
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end
end
