class CreateSubscriptionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_events do |t|
      t.string :notification_uuid, null: false
      t.string :transaction_id, null: false
      t.string :event_type, null: false
      t.string :product_id
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency
      t.datetime :purchase_date
      t.datetime :expires_date
      t.datetime :processed_at

      t.timestamps
    end

    add_index :subscription_events, :notification_uuid, unique: true
    add_index :subscription_events, :transaction_id
    add_index :subscription_events, :event_type
  end
end
