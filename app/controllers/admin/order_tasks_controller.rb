# frozen_string_literal: true

module Admin
  class OrderTasksController < BaseController
    skip_before_action :require_admin
    before_action :set_order_task

    def update
      unless allowed_to_update_order_task?
        return redirect_to(
          redirect_path_for_order_task,
          alert: 'Bạn không có quyền thay đổi trạng thái task này.'
        )
      end

      if @order_task.update(order_task_params)
        redirect_to redirect_path_for_order_task, notice: 'Cập nhật trạng thái task thành công.'
      else
        redirect_to redirect_path_for_order_task, alert: @order_task.errors.full_messages
      end
    end

    private

    def set_order_task
      @order_task = OrderTask.visible_to(current_user).find(params[:id])
    end

    def order_task_params
      params.expect(order_task: [ :is_completed ])
    end

    def allowed_to_update_order_task?
      return true if current_user.admin?

      ActiveModel::Type::Boolean.new.cast(order_task_params[:is_completed])
    end

    def redirect_path_for_order_task
      return member_order_tasks_path if params[:source] == 'member_tasks' && current_user.member?

      admin_order_service_path(@order_task.order_service, source: params[:source].presence)
    end
  end
end
