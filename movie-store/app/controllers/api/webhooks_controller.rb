module Api
  class WebhooksController < BaseController
    # POST /api/webhooks/apple
    def apple
      existing_event = SubscriptionEvent.find_by(notification_uuid: webhook_params[:notification_uuid])
      if existing_event
        render json: { status: "already_processed" }, status: :ok
        return
      end

      subscription = Subscription.find_by!(transaction_id: webhook_params[:transaction_id])

      ActiveRecord::Base.transaction do
        event = SubscriptionEvent.create!(
          notification_uuid: webhook_params[:notification_uuid],
          transaction_id: webhook_params[:transaction_id],
          event_type: webhook_params[:type],
          product_id: webhook_params[:product_id],
          amount: webhook_params[:amount],
          currency: webhook_params[:currency],
          purchase_date: webhook_params[:purchase_date],
          expires_date: webhook_params[:expires_date],
          processed_at: Time.current
        )

        case webhook_params[:type]
        when SubscriptionEvent::PURCHASE
          subscription.activate!(
            purchase_date: webhook_params[:purchase_date],
            expires_date: webhook_params[:expires_date],
            amount: webhook_params[:amount],
            currency: webhook_params[:currency]
          )
        when SubscriptionEvent::RENEW
          subscription.renew!(
            purchase_date: webhook_params[:purchase_date],
            expires_date: webhook_params[:expires_date],
            amount: webhook_params[:amount],
            currency: webhook_params[:currency]
          )
        when SubscriptionEvent::CANCEL
          subscription.cancel!
        else
          raise ActiveRecord::RecordInvalid, "Unknown event type: #{webhook_params[:type]}"
        end
      end

      render json: { status: "processed" }, status: :ok

    rescue ActiveRecord::RecordNotUnique
      render json: { status: "already_processed" }, status: :ok
    end

    private

    def webhook_params
      params.require(:webhook).permit(
        :notification_uuid, :type, :transaction_id, :product_id,
        :amount, :currency, :purchase_date, :expires_date
      )
    end
  end
end
