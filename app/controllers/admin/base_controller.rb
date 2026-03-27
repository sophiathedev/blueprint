# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout 'admin'

    before_action :require_authentication
    before_action :require_admin

    private

    def require_admin
      return redirect_member_task_management if redirect_member_task_management?
      return if current_user&.admin?

      redirect_to root_path, alert: 'Bạn không có quyền truy cập khu vực quản trị.'
    end

    def redirect_member_task_management?
      current_user&.member? && controller_path == 'admin/tasks' && action_name == 'index'
    end

    def redirect_member_task_management
      redirect_to member_order_tasks_path
    end
  end
end
