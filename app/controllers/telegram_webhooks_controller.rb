# frozen_string_literal: true

class TelegramWebhooksController < ActionController::API
  def create
    client = Telegram::Client.new

    unless client.webhook_secret_valid?(request.headers[Telegram::Client::SECRET_HEADER])
      Rails.logger.warn('Rejected Telegram webhook because the secret token is invalid.')
      return head :unauthorized
    end

    Telegram::WebhookProcessor.new(client: client).call(params.to_unsafe_h)
    head :ok
  rescue Telegram::Client::MissingConfigurationError
    head :ok
  rescue StandardError => error
    Rails.logger.error("Telegram webhook processing failed: #{error.class} - #{error.message}")
    head :ok
  end
end
