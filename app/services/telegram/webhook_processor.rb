# frozen_string_literal: true

module Telegram
  class WebhookProcessor
    START_COMMAND_PATTERN = %r{\A/start(?:@\w+)?(?:\s+(.+))?\z}.freeze

    def initialize(client: Client.new)
      @client = client
    end

    def call(payload)
      message = extract_message(payload)
      return if message.blank?

      text = message[:text].to_s.strip
      return unless text.start_with?('/start')

      chat = message[:chat].to_h
      chat_id = chat[:id]
      return if chat_id.blank?

      if chat[:type].to_s != 'private'
        client.send_message(
          chat_id:,
          text: 'Vui lòng mở chat riêng với bot rồi nhấn Start để hoàn tất kết nối Blueprint.'
        )
        return
      end

      token = extract_start_token(text)
      if token.blank?
        client.send_message(chat_id:, text: missing_token_message(chat_id))
        return
      end

      user = User.find_by_telegram_connection_token(token)
      if user.blank?
        client.send_message(
          chat_id:,
          text: 'Link kết nối đã hết hạn hoặc không hợp lệ. Hãy quay lại Blueprint và bấm Connect Telegram lại nhé.'
        )
        return
      end

      disconnect_existing_user_for_chat!(user, chat_id)
      user.complete_telegram_connection!(chat_id:)
      client.send_message(chat_id:, text: success_message(user))
    end

    private

    attr_reader :client

    def extract_message(payload)
      normalized_payload = payload.to_h.deep_symbolize_keys
      normalized_payload[:message] || normalized_payload[:edited_message]
    end

    def extract_start_token(text)
      text.match(START_COMMAND_PATTERN)&.captures&.first.to_s.strip.presence
    end

    def missing_token_message(chat_id)
      connected_user = User.find_by(telegram_chat_id: chat_id)
      return "Chat này hiện đã được kết nối với tài khoản #{connected_user.display_name}." if connected_user.present?

      'Hãy quay lại Blueprint và bấm Connect Telegram để lấy link kết nối mới.'
    end

    def disconnect_existing_user_for_chat!(user, chat_id)
      User.where.not(id: user.id).where(telegram_chat_id: chat_id).update_all(
        telegram_chat_id: nil,
        telegram_connected_at: nil,
        telegram_connection_token_digest: nil,
        telegram_connection_token_generated_at: nil,
        updated_at: Time.current
      )
    end

    def success_message(user)
      "Đã kết nối Telegram cho tài khoản #{user.display_name}. Từ bây giờ Blueprint có thể gửi thông báo riêng cho bạn tại đây."
    end
  end
end
