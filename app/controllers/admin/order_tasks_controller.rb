# frozen_string_literal: true

module Admin
  class OrderTasksController < BaseController
    include ActionView::RecordIdentifier

    skip_before_action :require_admin
    before_action :set_order_task

    def update
      unless allowed_to_update_order_task?
        return respond_order_task_update_error('Bạn không có quyền thay đổi trạng thái task này.')
      end

      completed_before_update = @order_task.is_completed?

      if @order_task.update(order_task_params)
        enqueue_completion_notification_if_needed(completed_before_update)
        respond_order_task_update_success
      else
        respond_order_task_update_error(@order_task.errors.full_messages)
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

    def enqueue_completion_notification_if_needed(completed_before_update)
      return if completed_before_update
      return unless @order_task.is_completed?

      NotifyAdminsTaskCompletedJob.perform_async(@order_task.id, current_user.id)
    end

    def respond_order_task_update_success
      respond_to do |format|
        format.html { redirect_to redirect_path_for_order_task, notice: 'Cập nhật trạng thái task thành công.' }
        format.turbo_stream do
          flash.now[:notice] = 'Cập nhật trạng thái task thành công.'
          render turbo_stream: order_task_turbo_stream_updates
        end
      end
    end

    def respond_order_task_update_error(message)
      respond_to do |format|
        format.html { redirect_to redirect_path_for_order_task, alert: message }
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: [
            turbo_stream.prepend(
              'flash_messages',
              partial: 'shared/flash_messages',
              locals: { flash: flash }
            )
          ], status: :unprocessable_entity
        end
      end
    end

    def order_task_turbo_stream_updates
      updates = [
        turbo_stream.prepend(
          'flash_messages',
          partial: 'shared/flash_messages',
          locals: { flash: flash }
        )
      ]

      if params[:source] == 'member_tasks'
        updates << turbo_stream.replace(
          dom_id(@order_task, :member_row),
          partial: 'member_order_tasks/order_task_table_row',
          locals: { order_task: @order_task }
        )
        updates << turbo_stream.replace(
          dom_id(@order_task, :member_card),
          partial: 'member_order_tasks/order_task_card',
          locals: { order_task: @order_task }
        )
      else
        updates << turbo_stream.replace(
          dom_id(@order_task, :admin_row),
          partial: 'admin/order_services/order_task_row',
          locals: {
            order_task: @order_task,
            order_service: @order_task.order_service,
            source: params[:source],
            highlight_current_task: params[:source] == 'dashboard' && @order_task.task.member_id == current_user.id
          }
        )
      end

      updates
    end
  end
end
