# frozen_string_literal: true

module Telegram
  class Notifier
    def initialize(client: Client.new)
      @client = client
    rescue Client::MissingConfigurationError
      @client = nil
    end

    def deliver_to(user, text:, **options)
      return false if client.blank? || user.blank? || user.telegram_chat_id.blank?

      client.send_message(chat_id: user.telegram_chat_id, text:, **options)
      true
    rescue Client::Error => error
      Rails.logger.warn("Telegram notification failed for user #{user.id}: #{error.message}")
      false
    end

    private

    attr_reader :client
  end
end
