class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.string :user_id, null: false
      t.string :transaction_id, null: false
      t.string :product_id, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :purchase_date
      t.datetime :expires_date
      t.string :currency
      t.decimal :amount, precision: 10, scale: 2

      t.timestamps
    end

    add_index :subscriptions, :transaction_id, unique: true
    add_index :subscriptions, :user_id
    add_index :subscriptions, [:user_id, :status]
    add_index :subscriptions, :expires_date
  end
end
