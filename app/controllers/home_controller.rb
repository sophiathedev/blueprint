# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    return unless user_signed_in?

    @partner_filter = params[:partner_id].to_s
    @priority_filter = params[:priority].to_s
    @deadline_filter = params[:deadline].to_s
    @deadline_days_filter = normalized_deadline_days_filter
    @deadline_from_days_filter = normalized_day_offset_param(:deadline_from_days)
    @deadline_to_days_filter = normalized_day_offset_param(:deadline_to_days)

    current_orders_scope = OrderService
      .joins(service: :partner)
      .where(completed_at: Time.current.change(sec: 0)..)
    current_orders_scope = current_orders_scope.where(
      id: OrderTask.for_user_order_services(current_user)
    ) unless current_user.admin?
    @partner_filter_options = current_orders_scope
      .distinct
      .reorder('partners.name ASC')
      .pluck('partners.name', 'partners.id')
    current_orders_scope = apply_dashboard_filters(current_orders_scope)
    @current_orders = current_orders_scope
      .includes(service: :partner)
      .order(priority_status: :desc, completed_at: :asc, created_at: :desc)
      .limit(12)

    @current_orders_count = current_orders_scope.count
    @urgent_orders_count = current_orders_scope.urgent.count
    @orders_due_today_count = current_orders_scope.where(completed_at: Time.zone.today.all_day).count
    @orders_due_tomorrow_count = current_orders_scope.where(completed_at: Time.zone.tomorrow.all_day).count
  end

  private

  def apply_dashboard_filters(scope)
    filtered_scope = scope

    if @partner_filter.present?
      filtered_scope = filtered_scope.where(services: { partner_id: @partner_filter })
    end

    if @priority_filter.present? && OrderService.priority_statuses.key?(@priority_filter)
      filtered_scope = filtered_scope.where(priority_status: OrderService.priority_statuses[@priority_filter])
    end

    case @deadline_filter
    when 'hours_4'
      filtered_scope.where(completed_at: Time.current.change(sec: 0)..4.hours.from_now)
    when 'today'
      filtered_scope.where(completed_at: Time.zone.today.all_day)
    when 'tomorrow'
      filtered_scope.where(completed_at: Time.zone.tomorrow.all_day)
    when 'next_3_days'
      filtered_scope.where(completed_at: Time.current.change(sec: 0)..3.days.from_now.end_of_day)
    when 'next_7_days'
      filtered_scope.where(completed_at: Time.current.change(sec: 0)..7.days.from_now.end_of_day)
    when 'next_14_days'
      filtered_scope.where(completed_at: Time.current.change(sec: 0)..14.days.from_now.end_of_day)
    when 'next_30_days'
      filtered_scope.where(completed_at: Time.current.change(sec: 0)..30.days.from_now.end_of_day)
    when 'within_days'
      return filtered_scope unless @deadline_days_filter.positive?

      filtered_scope.where(completed_at: Time.current.change(sec: 0)..@deadline_days_filter.days.from_now.end_of_day)
    when 'custom_range'
      return filtered_scope unless @deadline_from_days_filter.is_a?(Integer) && @deadline_to_days_filter.is_a?(Integer)

      from_days = [@deadline_from_days_filter, @deadline_to_days_filter].min
      to_days = [@deadline_from_days_filter, @deadline_to_days_filter].max

      range_start =
        if from_days.zero?
          Time.current.change(sec: 0)
        else
          from_days.days.from_now.beginning_of_day
        end

      filtered_scope.where(completed_at: range_start..to_days.days.from_now.end_of_day)
    else
      filtered_scope
    end
  end

  def normalized_deadline_days_filter
    days = params[:deadline_days].to_i
    return '' if days <= 0

    [days, 365].min
  end

  def normalized_day_offset_param(key)
    return '' if params[key].blank?

    days = params[key].to_i
    return 0 if days.negative?

    [days, 365].min
  end
end
