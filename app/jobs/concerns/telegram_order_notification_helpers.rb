# frozen_string_literal: true

require 'erb'

module TelegramOrderNotificationHelpers
  private

  def notification_reply_markup(order_service)
    order_url = order_service_url(order_service)
    return if order_url.blank?

    {
      inline_keyboard: [
        [
          {
            text: 'Mở Order',
            url: order_url
          }
        ]
      ]
    }
  end

  def order_service_url(order_service)
    url_options = Rails.application.routes.default_url_options.symbolize_keys
    host = url_options[:host].presence || notification_host
    return if host.blank?

    protocol = url_options[:protocol].presence || notification_protocol_for(host)
    port = url_options[:port]

    Rails.application.routes.url_helpers.admin_order_service_url(order_service, host:, protocol:, port:)
  end

  def notification_host
    configured_host = ENV['APP_DOMAIN'].presence || ENV['APP_HOST'].presence
    return configured_host if configured_host.present?

    Rails.application.config.hosts.find do |entry|
      entry.is_a?(String) && entry.exclude?('localhost') && entry.exclude?('.test')
    end
  end

  def notification_protocol_for(host)
    return ENV['APP_PROTOCOL'] if ENV['APP_PROTOCOL'].present?
    return 'https' if host.include?('ngrok-free.app')

    'http'
  end

  def escaped(text)
    ERB::Util.html_escape(text.to_s)
  end
end
