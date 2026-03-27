# frozen_string_literal: true

class NotifyAdminsNewOrderJob
  include Sidekiq::Job
  include ActionView::RecordIdentifier
  include TelegramOrderNotificationHelpers

  sidekiq_options queue: :default

  def perform(order_service_id)
    order_service = OrderService.includes(service: :partner, order_tasks: { task: :member }).find_by(id: order_service_id)
    return if order_service.blank?

    notifier = Telegram::Notifier.new

    notify_admins(notifier, order_service)
    notify_assigned_members(notifier, order_service)
  end

  private

  def notify_admins(notifier, order_service)
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

  def notify_assigned_members(notifier, order_service)
    order_service.order_tasks.group_by { |order_task| order_task.task.member_id }.each_value do |member_order_tasks|
      member = member_order_tasks.first.task.member
      next if member.blank? || !member.telegram_connected?

      notifier.deliver_to(
        member,
        text: member_notification_message(order_service, member_order_tasks),
        parse_mode: 'HTML',
        disable_web_page_preview: true,
        reply_markup: notification_reply_markup(order_service)
      )
    end
  end

  def notification_message(order_service)
    [
      '🆕 <b>Order mới</b>',
      "📦 <b>Dịch vụ:</b> #{escaped(order_service.service.name)}",
      "🤝 <b>Đối tác:</b> #{escaped(order_service.service.partner.name)}",
      "👤 <b>PIC:</b> #{escaped(order_service.partner_assignee_name)}",
      "#{priority_emoji(order_service)} <b>Ưu tiên:</b> #{escaped(priority_label(order_service))}",
      "⏰ <b>Deadline:</b> #{escaped(I18n.l(order_service.completed_at, format: :long))}",
      notes_line(order_service)
    ].compact.join("\n")
  end

  def member_notification_message(order_service, member_order_tasks)
    [
      '🆕 <b>Bạn có order mới cần theo dõi</b>',
      'Các task bạn phụ trách trong order này đã sẵn sàng để xử lý.',
      "📦 <b>Dịch vụ:</b> #{escaped(order_service.service.name)}",
      "🤝 <b>Đối tác:</b> #{escaped(order_service.service.partner.name)}",
      "👤 <b>PIC:</b> #{escaped(order_service.partner_assignee_name)}",
      "#{priority_emoji(order_service)} <b>Ưu tiên:</b> #{escaped(priority_label(order_service))}",
      "⏰ <b>Deadline:</b> #{escaped(I18n.l(order_service.completed_at, format: :long))}",
      "🧩 <b>Task bạn phụ trách:</b>\n#{task_lines(member_order_tasks)}",
      notes_line(order_service)
    ].compact.join("\n")
  end

  def task_lines(member_order_tasks)
    member_order_tasks
      .sort_by { |order_task| [ order_task.task.name.to_s, order_task.id ] }
      .each_with_index
      .map do |order_task, index|
        "#{index + 1}. #{task_link(order_task)}"
      end
      .join("\n")
  end

  def task_link(order_task)
    order_url = order_service_url(order_task.order_service)
    task_url = [ order_url, dom_id(order_task, :admin_row) ].join('#')

    %(<a href="#{escaped(task_url)}">#{escaped(order_task.task.name)}</a>)
  end

  def notes_line(order_service)
    return if order_service.notes.blank?

    "📝 <b>Ghi chú:</b> #{escaped(order_service.notes)}"
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
end
