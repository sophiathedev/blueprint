# frozen_string_literal: true

module Admin
  class WorkTrackingController < BaseController
    def index
      task_scope = OrderTask
        .joins(task: [:member, { service: :partner }])
        .includes(:order_service, task: [:member, { service: :partner }])
        .distinct

      @task_filter = normalized_task_filter
      @query = params[:q].to_s.strip
      @selected_member_id = normalized_member_id

      @total_order_tasks_count = task_scope.count
      @pending_order_tasks_count = task_scope.where(is_completed: false).count
      @overdue_order_tasks_count = task_scope.where(is_overdue: true).count
      @completed_order_tasks_count = task_scope.where(is_completed: true).count

      @member_summaries = build_member_summaries(task_scope)
      @selected_member = @member_summaries.find { |summary| summary[:member].id == @selected_member_id }&.fetch(:member, nil)

      filtered_task_scope = task_scope
      filtered_task_scope = filtered_task_scope.where(tasks: { member_id: @selected_member_id }) if @selected_member_id.present?
      filtered_task_scope = apply_search_filter(apply_task_filter(filtered_task_scope))

      @order_tasks = filtered_task_scope.sort_by do |order_task|
        [
          order_task.is_completed? ? 1 : 0,
          order_task.is_overdue? ? 0 : 1,
          order_task.order_service.completed_at,
          order_task.task.member.display_name.to_s.downcase,
          order_task.id
        ]
      end
    end

    private

    def normalized_task_filter
      filter = params[:filter].to_s
      return 'all' unless %w[all pending overdue completed].include?(filter)

      filter
    end

    def normalized_member_id
      member_id = params[:member_id].to_i
      return '' unless member_id.positive?

      member_id
    end

    def apply_task_filter(scope)
      case @task_filter
      when 'pending'
        scope.where(is_completed: false)
      when 'overdue'
        scope.where(is_overdue: true)
      when 'completed'
        scope.where(is_completed: true)
      else
        scope
      end
    end

    def apply_search_filter(scope)
      return scope if @query.blank?

      sanitized_query = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope.where(
        'tasks.name ILIKE :query OR partners.name ILIKE :query OR users.name ILIKE :query OR users.email ILIKE :query',
        query: sanitized_query
      )
    end

    def build_member_summaries(scope)
      scope.to_a.group_by { |order_task| order_task.task.member }.filter_map do |member, member_tasks|
        next if member.blank?

        {
          member:,
          total_count: member_tasks.size,
          pending_count: member_tasks.count { |task| !task.is_completed? },
          overdue_count: member_tasks.count(&:is_overdue?),
          completed_count: member_tasks.count(&:is_completed?)
        }
      end.sort_by { |summary| summary[:member].display_name.to_s.downcase }
    end
  end
end
