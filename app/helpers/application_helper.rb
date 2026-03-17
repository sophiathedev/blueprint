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
        active: controller_path == 'admin/partners',
        icon: 'handshake'
      }
    ]
  end
end
