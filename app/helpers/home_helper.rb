# frozen_string_literal: true

module HomeHelper
  def dashboard_priority_filter_options
    [
      ['Tất cả mức ưu tiên', ''],
      ['Khẩn cấp', 'urgent'],
      ['Cao', 'high'],
      ['Trung bình', 'medium'],
      ['Thấp', 'low']
    ]
  end

  def dashboard_deadline_filter_options
    [
      ['Tất cả deadline', ''],
      ['Trong 4 giờ tới', 'hours_4'],
      ['Hôm nay', 'today'],
      ['Ngày mai', 'tomorrow'],
      ['Trong 3 ngày tới', 'next_3_days'],
      ['Trong 7 ngày tới', 'next_7_days'],
      ['Trong 14 ngày tới', 'next_14_days'],
      ['Trong 30 ngày tới', 'next_30_days'],
      ['Trong số ngày tới', 'within_days'],
      ['Khoảng ngày chi tiết', 'custom_range']
    ]
  end

  def dashboard_order_datetime(value)
    I18n.l(value, format: :long)
  end

  def dashboard_order_time(value)
    I18n.l(value, format: :time)
  end

  def dashboard_order_status(order_service)
    completed_at = order_service.completed_at
    now = Time.current.change(sec: 0)

    if completed_at <= now + 4.hours
      {
        label: 'Sắp đến hạn',
        container_class: 'border-rose-200 bg-rose-50 text-rose-700',
        dot_class: 'bg-rose-500',
        icon: 'clock-3',
        icon_container_class: 'bg-rose-50 text-rose-700 ring-1 ring-rose-200'
      }
    elsif completed_at.to_date == Time.zone.today
      {
        label: 'Trong hôm nay',
        container_class: 'border-amber-200 bg-amber-50 text-amber-700',
        dot_class: 'bg-amber-500',
        icon: 'sun',
        icon_container_class: 'bg-amber-50 text-amber-700 ring-1 ring-amber-200'
      }
    elsif completed_at.to_date == Time.zone.tomorrow
      {
        label: 'Ngày mai',
        container_class: 'border-sky-200 bg-sky-50 text-sky-700',
        dot_class: 'bg-sky-500',
        icon: 'calendar-days',
        icon_container_class: 'bg-sky-50 text-sky-700 ring-1 ring-sky-200'
      }
    else
      {
        label: 'Đã lên lịch',
        container_class: 'border-emerald-200 bg-emerald-50 text-emerald-700',
        dot_class: 'bg-emerald-500',
        icon: 'calendar-check-2',
        icon_container_class: 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200'
      }
    end
  end

  def dashboard_order_priority(order_service)
    case order_service.priority_status
    when 'urgent'
      {
        label: 'Khẩn cấp',
        tooltip: 'Mức độ ưu tiên: Khẩn cấp',
        container_class: 'border-rose-200 bg-rose-50 text-rose-700',
        icon: 'triangle-alert',
        icon_container_class: 'bg-rose-100 text-rose-700 ring-1 ring-rose-200'
      }
    when 'high'
      {
        label: 'Cao',
        tooltip: 'Mức độ ưu tiên: Cao',
        container_class: 'border-emerald-200 bg-emerald-50 text-emerald-700',
        icon: 'arrow-up',
        icon_container_class: 'bg-emerald-100 text-emerald-700 ring-1 ring-emerald-200'
      }
    when 'medium'
      {
        label: 'Trung bình',
        tooltip: 'Mức độ ưu tiên: Trung bình',
        container_class: 'border-amber-200 bg-amber-50 text-amber-700',
        icon: 'arrow-right',
        icon_container_class: 'bg-amber-100 text-amber-700 ring-1 ring-amber-200'
      }
    else
      {
        label: 'Thấp',
        tooltip: 'Mức độ ưu tiên: Thấp',
        container_class: 'border-stone-200 bg-stone-100 text-stone-600',
        icon: 'arrow-down',
        icon_container_class: 'bg-sky-100 text-sky-700 ring-1 ring-sky-200'
      }
    end
  end

  def dashboard_order_due_text(order_service)
    completed_at = order_service.completed_at

    if completed_at <= Time.current.change(sec: 0) + 4.hours
      "Cần ưu tiên xử lý trước #{dashboard_order_time(completed_at)} hôm nay"
    elsif completed_at.to_date == Time.zone.today
      "Được hẹn trong hôm nay vào lúc #{dashboard_order_time(completed_at)}"
    elsif completed_at.to_date == Time.zone.tomorrow
      "Hẹn vào ngày mai lúc #{dashboard_order_time(completed_at)}"
    else
      "Được đặt cho #{dashboard_order_datetime(completed_at)}"
    end
  end

  def dashboard_order_remaining_time(order_service)
    completed_at = order_service.completed_at
    now = Time.current.change(sec: 0)
    remaining_seconds = (completed_at - now).to_i

    return 'Đã đến hạn' if remaining_seconds <= 0

    total_minutes = (remaining_seconds / 60.0).ceil
    days = total_minutes / (24 * 60)
    hours = (total_minutes % (24 * 60)) / 60
    minutes = total_minutes % 60

    parts = []
    parts << "#{days} ngày" if days.positive?
    parts << "#{hours} giờ" if hours.positive?
    parts << "#{minutes} phút" if minutes.positive? || parts.empty?

    "Còn #{parts.first(2).join(' ')}"
  end

  def dashboard_order_remaining_time_card(order_service)
    completed_at = order_service.completed_at
    now = Time.current.change(sec: 0)

    if completed_at <= now + 4.hours
      {
        card_class: 'border-rose-200 bg-rose-50',
        eyebrow_class: 'text-rose-500',
        value_class: 'text-rose-700',
        meta_class: 'text-rose-600/80'
      }
    elsif completed_at <= now + 1.day
      {
        card_class: 'border-amber-200 bg-amber-50',
        eyebrow_class: 'text-amber-500',
        value_class: 'text-amber-700',
        meta_class: 'text-amber-700/75'
      }
    elsif completed_at <= now + 3.days
      {
        card_class: 'border-orange-200 bg-orange-50',
        eyebrow_class: 'text-orange-500',
        value_class: 'text-orange-700',
        meta_class: 'text-orange-700/75'
      }
    else
      {
        card_class: 'border-emerald-200 bg-emerald-50',
        eyebrow_class: 'text-emerald-500',
        value_class: 'text-emerald-700',
        meta_class: 'text-emerald-700/75'
      }
    end
  end

  def dashboard_order_task_overdue_badge_text(order_task)
    return unless order_task.is_overdue?

    deadline = order_task.order_service.completed_at
    reference_time = order_task.mark_completed_at.presence || Time.current.change(sec: 0)
    overdue_seconds = (reference_time - deadline).to_i

    return 'Trễ hạn' if overdue_seconds <= 0

    total_minutes = (overdue_seconds / 60.0).ceil
    days = total_minutes / (24 * 60)
    hours = (total_minutes % (24 * 60)) / 60
    minutes = total_minutes % 60

    parts = []
    parts << "#{days} ngày" if days.positive?
    parts << "#{hours} giờ" if hours.positive?
    parts << "#{minutes} phút" if minutes.positive? || parts.empty?

    "Trễ hạn (#{parts.first(2).join(' ')})"
  end
end
