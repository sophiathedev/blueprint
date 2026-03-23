# frozen_string_literal: true

class OrderDeadlineMissJob
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform(order_service_id)
    order_service = OrderService.find_by(id: order_service_id)
    return if order_service.blank? || order_service.completed_at.blank?

    order_service.order_tasks.where(is_completed: false, is_overdue: false).update_all(
      is_overdue: true,
      updated_at: Time.current
    )
    order_service.update_column(:deadline_check_job_id, nil)
  end
end
