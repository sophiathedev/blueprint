# frozen_string_literal: true

class MemberOrderTasksController < ApplicationController
  layout 'admin'

  before_action :require_authentication
  before_action :require_member

  def index
    reference_time = Time.current.change(sec: 0)
    task_scope = OrderTask
      .visible_to(current_user)
      .joins(:order_service, task: { service: :partner })
      .includes(:order_service, task: { service: :partner })
      .distinct
    @task_filter = normalized_task_filter
    @deadline_filter = normalized_deadline_filter
    @query = params[:q].to_s.strip

    @total_order_tasks_count = task_scope.count
    @pending_order_tasks_count = task_scope.where(is_completed: false).count
    @overdue_order_tasks_count = task_scope.where(is_overdue: true).count
    @completed_order_tasks_count = task_scope.where(is_completed: true).count

    filtered_task_scope = apply_search_filter(apply_deadline_filter(apply_task_filter(task_scope), reference_time))

    @order_tasks = filtered_task_scope.sort_by do |order_task|
      [
        order_task.is_completed? ? 1 : 0,
        order_task.is_overdue? ? 0 : 1,
        order_task.order_service.completed_at,
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

  def normalized_deadline_filter
    filter = params[:deadline].to_s
    return '' unless %w[overdue today tomorrow next_3_days next_7_days].include?(filter)

    filter
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

  def apply_deadline_filter(scope, reference_time)
    case @deadline_filter
    when 'overdue'
      scope.where('order_services.completed_at < ?', reference_time)
    when 'today'
      scope.where(order_services: { completed_at: Time.zone.today.all_day })
    when 'tomorrow'
      scope.where(order_services: { completed_at: Time.zone.tomorrow.all_day })
    when 'next_3_days'
      scope.where(order_services: { completed_at: reference_time..3.days.from_now.end_of_day })
    when 'next_7_days'
      scope.where(order_services: { completed_at: reference_time..7.days.from_now.end_of_day })
    else
      scope
    end
  end

  def apply_search_filter(scope)
    return scope if @query.blank?

    sanitized_query = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    scope.where(
      'tasks.name ILIKE :query OR partners.name ILIKE :query OR order_services.customer_domain ILIKE :query',
      query: sanitized_query
    )
  end

  def require_member
    return if current_user&.member?

    redirect_to root_path, alert: 'Màn hình này chỉ dành cho member.'
  end
end
