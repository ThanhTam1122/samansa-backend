class Subscription < ApplicationRecord
  # Statuses
  PENDING   = "pending".freeze   # Client reported purchase, awaiting Apple webhook
  ACTIVE    = "active".freeze    # Apple confirmed via PURCHASE/RENEW webhook
  CANCELLED = "cancelled".freeze # Apple sent CANCEL webhook; access until expires_date

  STATUSES = [PENDING, ACTIVE, CANCELLED].freeze

  has_many :subscription_events, primary_key: :transaction_id, foreign_key: :transaction_id

  validates :user_id, presence: true
  validates :transaction_id, presence: true, uniqueness: true
  validates :product_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :active_or_grace, -> {
    where(status: ACTIVE)
      .or(where(status: CANCELLED).where("expires_date > ?", Time.current))
  }

  def viewable?
    active? || (cancelled? && expires_date.present? && expires_date > Time.current)
  end

  def active?
    status == ACTIVE
  end

  def pending?
    status == PENDING
  end

  def cancelled?
    status == CANCELLED
  end

  def activate!(purchase_date:, expires_date:, amount: nil, currency: nil)
    update!(
      status: ACTIVE,
      purchase_date: purchase_date,
      expires_date: expires_date,
      amount: amount,
      currency: currency
    )
  end

  def renew!(purchase_date:, expires_date:, amount: nil, currency: nil)
    update!(
      status: ACTIVE,
      purchase_date: purchase_date,
      expires_date: expires_date,
      amount: amount,
      currency: currency
    )
  end

  def cancel!
    update!(status: CANCELLED)
  end
end
