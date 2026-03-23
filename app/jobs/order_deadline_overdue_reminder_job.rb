# frozen_string_literal: true

class OrderDeadlineOverdueReminderJob
  include Sidekiq::Job
  include TelegramOrderNotificationHelpers

  sidekiq_options queue: :default

  def perform(order_service_id)
    order_service = OrderService.includes(service: :partner, order_tasks: { task: :member }).find_by(id: order_service_id)
    return if order_service.blank? || order_service.completed_at.blank?

    order_service.remove_scheduled_deadline_job_id!(jid)

    pending_order_tasks = order_service.order_tasks.where(is_completed: false).to_a
    return if pending_order_tasks.empty?

    OrderTask.where(id: pending_order_tasks.map(&:id)).update_all(is_overdue: true, updated_at: Time.current)
    notify_assigned_members(order_service, pending_order_tasks)

    next_job_id = self.class.perform_at(1.day.from_now.change(sec: 0), order_service.id)
    order_service.add_scheduled_deadline_job_id!(next_job_id)
  end

  private

  def notify_assigned_members(order_service, pending_order_tasks)
    notifier = Telegram::Notifier.new

    pending_order_tasks.group_by { |order_task| order_task.task.member }.each do |member, member_order_tasks|
      next if member.blank? || !member.telegram_connected?

      notifier.deliver_to(
        member,
        text: reminder_message(order_service, member_order_tasks),
        parse_mode: 'HTML',
        disable_web_page_preview: true,
        reply_markup: notification_reply_markup(order_service)
      )
    end
  end

  def reminder_message(order_service, member_order_tasks)
    [
      '🔁 <b>Nhắc lại task trễ hạn</b>',
      'Task của bạn vẫn chưa hoàn thành sau deadline. Mình nhắc bạn xử lý tiếp nhé.',
      "📦 <b>Dịch vụ:</b> #{escaped(order_service.service.name)}",
      "🤝 <b>Đối tác:</b> #{escaped(order_service.service.partner.name)}",
      "🕒 <b>Deadline:</b> #{escaped(I18n.l(order_service.completed_at, format: :long))}",
      "🧩 <b>Task chưa hoàn thành:</b>\n#{task_lines(member_order_tasks)}"
    ].join("\n")
  end

  def task_lines(member_order_tasks)
    member_order_tasks.map { |order_task| "• #{escaped(order_task.task.name)}" }.join("\n")
  end
end
