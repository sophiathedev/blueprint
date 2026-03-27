# frozen_string_literal: true

module GoogleSheets
  class ServiceSnapshotBuilder
    GOOGLE_SHEETS_TIME_ZONE = 'Asia/Ho_Chi_Minh'

    ORDER_HEADERS = [
      'Đối tác',
      'Dịch vụ',
      'Công việc',
      'Người phụ trách',
      'PIC đối tác',
      'Link Google Sheet',
      'Domain khách hàng',
      'Mức độ ưu tiên',
      'Deadline',
      'Đã hoàn thành',
      'Trễ hạn',
      'Thời gian hoàn thành',
      'Ghi chú order',
      'Ngày tạo',
      'Cập nhật lúc'
    ].freeze

    def initialize(service)
      @service = service
    end

    def order_rows
      [ORDER_HEADERS] + order_tasks.map do |order_task|
        [
          service.partner.name,
          service.name,
          order_task.task.name,
          order_task.task.member&.display_name,
          order_task.order_service.partner_assignee_name,
          order_task.order_service.google_sheet_link.to_s,
          order_task.order_service.customer_domain.to_s,
          priority_label(order_task.order_service.priority_status),
          format_time(order_task.order_service.completed_at),
          boolean_label(order_task.is_completed),
          boolean_label(order_task.is_overdue),
          format_time(order_task.mark_completed_at),
          order_task.order_service.notes.to_s,
          format_time(order_task.created_at),
          format_time(order_task.updated_at)
        ]
      end
    end

    def has_order_rows?
      order_tasks.any?
    end

    private

    attr_reader :service

    def order_tasks
      @order_tasks ||= OrderTask
        .joins(:task)
        .includes(task: :member, order_service: :service)
        .where(
          order_service_id: service.order_services.select(:id),
          task_id: service.tasks.select(:id)
        )
        .order(:order_service_id, 'tasks.name ASC', :id)
        .to_a
    end

    def format_time(time)
      time&.in_time_zone(GOOGLE_SHEETS_TIME_ZONE)&.iso8601
    end

    def boolean_label(value)
      value ? 'Có' : 'Không'
    end

    def priority_label(priority_status)
      case priority_status.to_s
      when 'low'
        'Thấp'
      when 'medium'
        'Trung bình'
      when 'high'
        'Cao'
      when 'urgent'
        'Khẩn cấp'
      else
        priority_status.to_s
      end
    end
  end
end
