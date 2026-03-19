# frozen_string_literal: true

module ApplicationHelper
  def sidebar_items
    items = [
      {
        label: 'Dashboard',
        href: root_path,
        active: current_page?(root_path),
        icon: 'layout-dashboard'
      }
    ]

    return items unless user_signed_in? && current_user.admin?

    items + [
      {
        label: 'Đối tác',
        href: admin_partners_path,
        active: controller_path.in?(%w[admin/partners admin/services admin/tasks]),
        icon: 'handshake'
      },
      {
        label: 'Thành viên',
        href: admin_members_path,
        active: controller_path == 'admin/members',
        icon: 'users-round'
      }
    ]
  end
end
