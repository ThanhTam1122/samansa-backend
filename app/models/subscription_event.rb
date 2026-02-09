class SubscriptionEvent < ApplicationRecord
  PURCHASE = "PURCHASE".freeze
  RENEW    = "RENEW".freeze
  CANCEL   = "CANCEL".freeze

  EVENT_TYPES = [PURCHASE, RENEW, CANCEL].freeze

  belongs_to :subscription, primary_key: :transaction_id, foreign_key: :transaction_id, optional: true

  validates :notification_uuid, presence: true, uniqueness: true
  validates :transaction_id, presence: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }

  scope :for_transaction, ->(txn_id) { where(transaction_id: txn_id) }

  def processed?
    processed_at.present?
  end
end
