# frozen_string_literal: true

require 'erb'

class NotifyAdminsNewOrderJob
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform(order_service_id)
    order_service = OrderService.includes(service: :partner).find_by(id: order_service_id)
    return if order_service.blank?

    notifier = Telegram::Notifier.new

    User.admin.telegram_connected.find_each do |admin|
      notifier.deliver_to(
        admin,
        text: notification_message(order_service),
        parse_mode: 'HTML',
        disable_web_page_preview: true,
        reply_markup: notification_reply_markup(order_service)
      )
    end
  end

  private

  def notification_message(order_service)
    [
      '🆕 <b>Order mới</b>',
      "📦 <b>Dịch vụ:</b> #{escaped(order_service.service.name)}",
      "🤝 <b>Đối tác:</b> #{escaped(order_service.service.partner.name)}",
      "👤 <b>PIC:</b> #{escaped(order_service.partner_assignee_name)}",
      "#{priority_emoji(order_service)} <b>Ưu tiên:</b> #{escaped(priority_label(order_service))}",
      "⏰ <b>Deadline:</b> #{escaped(I18n.l(order_service.completed_at, format: :long))}"
    ].join("\n")
  end

  def priority_label(order_service)
    case order_service.priority_status.to_s
    when 'low'
      'Thấp'
    when 'medium'
      'Trung bình'
    when 'high'
      'Cao'
    when 'urgent'
      'Khẩn cấp'
    else
      order_service.priority_status.to_s.humanize
    end
  end

  def priority_emoji(order_service)
    case order_service.priority_status.to_s
    when 'low'
      '🟢'
    when 'medium'
      '🟡'
    when 'high'
      '🟠'
    when 'urgent'
      '🔴'
    else
      '🔹'
    end
  end

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
