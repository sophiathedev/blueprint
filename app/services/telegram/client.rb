# frozen_string_literal: true

require 'erb'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module Telegram
  class Client
    API_BASE_URL = 'https://api.telegram.org'.freeze
    SECRET_HEADER = 'X-Telegram-Bot-Api-Secret-Token'.freeze

    class MissingConfigurationError < StandardError; end
    class Error < StandardError; end

    def initialize(token: AppSetting.current.telegram_api_key)
      @token = token.to_s.strip
      raise MissingConfigurationError, 'Telegram bot chưa được cấu hình trong Settings.' if @token.blank?
    end

    def deep_link_for(connection_token)
      "https://t.me/#{bot_username}?start=#{ERB::Util.url_encode(connection_token.to_s)}"
    end

    def register_webhook!(base_url:)
      post!('setWebhook', url: webhook_url(base_url), secret_token: webhook_secret)
    end

    def remove_webhook!
      post!('deleteWebhook', drop_pending_updates: false)
    end

    def send_message(chat_id:, text:, **options)
      post!('sendMessage', { chat_id:, text: }.merge(options))
    end

    def webhook_secret_valid?(secret_token)
      normalized_secret = secret_token.to_s
      return false if normalized_secret.blank?

      ActiveSupport::SecurityUtils.secure_compare(normalized_secret, webhook_secret)
    end

    private

    attr_reader :token

    def bot_username
      username = bot_profile.fetch('username', '').to_s.delete_prefix('@')
      raise Error, 'Telegram bot chưa có username hợp lệ.' if username.blank?

      username
    end

    def bot_profile
      @bot_profile ||= post!('getMe')
    end

    def webhook_url(base_url)
      "#{base_url.to_s.chomp('/')}#{Rails.application.routes.url_helpers.telegram_webhook_path}"
    end

    def webhook_secret
      @webhook_secret ||= OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, token)
    end

    def post!(method_name, payload = {})
      response = http_client.post(api_uri(method_name), request_body(payload), request_headers)
      parsed_response = parse_response(response)

      return parsed_response.fetch('result', true) if response.is_a?(Net::HTTPSuccess) && parsed_response['ok']

      raise Error, parsed_response['description'].presence || 'Không thể kết nối tới Telegram Bot API.'
    rescue JSON::ParserError, Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED,
           EOFError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           SocketError => error
      raise Error, "Không thể kết nối tới Telegram Bot API: #{error.message}"
    end

    def http_client
      @http_client ||= Net::HTTP
    end

    def api_uri(method_name)
      URI("#{API_BASE_URL}/bot#{token}/#{method_name}")
    end

    def request_body(payload)
      payload.to_json
    end

    def request_headers
      {
        'Content-Type' => 'application/json'
      }
    end

    def parse_response(response)
      JSON.parse(response.body.presence || '{}')
    end
  end
end
