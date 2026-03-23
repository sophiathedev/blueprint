# frozen_string_literal: true

require 'erb'

class NotifyAdminsTaskCompletedJob
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform(order_task_id, completed_by_user_id = nil)
    order_task = OrderTask.includes(order_service: { service: :partner }, task: :member).find_by(id: order_task_id)
    return if order_task.blank? || !order_task.is_completed?

    completed_by_user = User.find_by(id: completed_by_user_id) if completed_by_user_id.present?
    notifier = Telegram::Notifier.new

    User.admin.telegram_connected.find_each do |admin|
      notifier.deliver_to(
        admin,
        text: notification_message(order_task, completed_by_user),
        parse_mode: 'HTML',
        disable_web_page_preview: true,
        reply_markup: notification_reply_markup(order_task.order_service)
      )
    end

    notify_task_assignee(notifier, order_task, completed_by_user)
  end

  private

  def notification_message(order_task, completed_by_user)
    [
      '✅ <b>Task đã hoàn thành</b>',
      "🧩 <b>Task:</b> #{escaped(order_task.task.name)}",
      "📦 <b>Dịch vụ:</b> #{escaped(order_task.order_service.service.name)}",
      "🤝 <b>Đối tác:</b> #{escaped(order_task.order_service.service.partner.name)}",
      "👤 <b>Người phụ trách:</b> #{escaped(user_label(order_task.task.member) || 'Chưa gán')}",
      "🙋 <b>Người thao tác:</b> #{escaped(user_label(completed_by_user) || user_label(order_task.task.member) || 'Hệ thống')}",
      "🕒 <b>Hoàn thành lúc:</b> #{escaped(I18n.l(order_task.mark_completed_at || Time.current, format: :long))}"
    ].join("\n")
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

  def user_label(user)
    return if user.blank?
    return "#{user.display_name} (#{user.email})" if user.email.present?

    user.display_name
  end

  def notify_task_assignee(notifier, order_task, completed_by_user)
    assignee = order_task.task.member
    return if assignee.blank? || !assignee.telegram_connected?

    notifier.deliver_to(
      assignee,
      text: assignee_notification_message(order_task, completed_by_user),
      parse_mode: 'HTML',
      disable_web_page_preview: true,
      reply_markup: notification_reply_markup(order_task.order_service)
    )
  end

  def assignee_notification_message(order_task, completed_by_user)
    headline =
      if completed_by_user&.admin?
        '🎉 <b>Hooray! Bạn vừa được admin đánh dấu là hoàn thành task</b>'
      else
        '🎉 <b>Hooray! Task của bạn vừa được đánh dấu là hoàn thành</b>'
      end

    [
      headline,
      "🧩 <b>Task:</b> #{escaped(order_task.task.name)}",
      "📦 <b>Dịch vụ:</b> #{escaped(order_task.order_service.service.name)}",
      "🤝 <b>Đối tác:</b> #{escaped(order_task.order_service.service.partner.name)}",
      "🙋 <b>Người thao tác:</b> #{escaped(user_label(completed_by_user) || 'Hệ thống')}",
      "🕒 <b>Hoàn thành lúc:</b> #{escaped(I18n.l(order_task.mark_completed_at || Time.current, format: :long))}"
    ].join("\n")
  end
end
