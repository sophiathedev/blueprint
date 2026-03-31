# frozen_string_literal: true

module MemberOrderTasksHelper
  def member_order_task_deadline_filter_options
    [
      ['Tất cả', ''],
      ['Quá hạn', 'overdue'],
      ['Hôm nay', 'today'],
      ['Ngày mai', 'tomorrow'],
      ['3 ngày tới', 'next_3_days'],
      ['7 ngày tới', 'next_7_days']
    ]
  end
end
