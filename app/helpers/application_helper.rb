# frozen_string_literal: true

module ApplicationHelper
  def back_path(fallback)
    referer = request.referer
    return fallback if referer.blank?

    uri = URI.parse(referer)
    return fallback if uri.host.present? && uri.host != request.host

    candidate = +"#{uri.path.presence || '/'}"
    candidate << "?#{uri.query}" if uri.query.present?
    return fallback if candidate == request.fullpath

    candidate
  rescue URI::InvalidURIError
    fallback
  end

  def sidebar_items
    now = Time.current.change(sec: 0)
    dashboard_scope = OrderService.where(completed_at: now..)

    if user_signed_in? && current_user.member?
      dashboard_scope = dashboard_scope.where(id: OrderTask.for_user_order_services(current_user))
    end

    dashboard_badge =
      if user_signed_in?
        active_orders_count = dashboard_scope.count
        active_orders_count if active_orders_count.positive?
      end

    items = [
      {
        label: 'Dashboard',
        href: root_path,
        active: current_page?(root_path),
        icon: 'layout-dashboard',
        badge: dashboard_badge.presence
      }
    ]

    if user_signed_in? && current_user.member?
      member_tasks_badge = OrderTask.visible_to(current_user).where(is_completed: false).count

      items << {
        label: 'Quản lý Task',
        href: member_order_tasks_path,
        active: controller_path == 'member_order_tasks',
        icon: 'list-checks',
        badge: member_tasks_badge.positive? ? member_tasks_badge : nil
      }
    end

    return items unless user_signed_in? && current_user.admin?

    items + [
      {
        label: 'Đối tác',
        href: admin_partners_path,
        active: controller_path.in?(%w[admin/partners admin/services admin/tasks]),
        icon: 'handshake'
      },
      {
        label: 'Dịch vụ',
        href: admin_services_path,
        active: controller_path == 'admin/all_services',
        icon: 'briefcase-business'
      },
      {
        label: 'Thành viên',
        href: admin_members_path,
        active: controller_path == 'admin/members',
        icon: 'users-round'
      },
      {
        label: 'Settings',
        href: admin_settings_path,
        active: controller_path == 'admin/settings',
        icon: 'settings'
      }
    ]
  end
end
