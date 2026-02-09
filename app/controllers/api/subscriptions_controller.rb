module Api
  class SubscriptionsController < BaseController
    # POST /api/subscriptions
    def create
      subscription = Subscription.find_by(transaction_id: subscription_params[:transaction_id])

      if subscription
        render json: serialize(subscription), status: :ok
        return
      end

      subscription = Subscription.create!(
        user_id: subscription_params[:user_id],
        transaction_id: subscription_params[:transaction_id],
        product_id: subscription_params[:product_id],
        status: Subscription::PENDING
      )

      render json: serialize(subscription), status: :created
    end

    # GET /api/subscriptions/:user_id
    def show
      subscriptions = Subscription.for_user(params[:user_id])
                                  .order(created_at: :desc)

      render json: {
        user_id: params[:user_id],
        subscriptions: subscriptions.map { |s| serialize(s) }
      }
    end

    private

    def subscription_params
      params.require(:subscription).permit(:user_id, :transaction_id, :product_id)
    end

    def serialize(subscription)
      {
        id: subscription.id,
        user_id: subscription.user_id,
        transaction_id: subscription.transaction_id,
        product_id: subscription.product_id,
        status: subscription.status,
        viewable: subscription.viewable?,
        purchase_date: subscription.purchase_date&.iso8601,
        expires_date: subscription.expires_date&.iso8601,
        created_at: subscription.created_at.iso8601,
        updated_at: subscription.updated_at.iso8601
      }
    end
  end
end
