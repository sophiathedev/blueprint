# frozen_string_literal: true

require 'test_helper'

class OrderDeadlineMissJobTest < ActiveSupport::TestCase
  test 'marks all unfinished order tasks as overdue when deadline is reached' do
    service = build_service
    member = build_member('Deadline Member')

    completed_task = service.tasks.create!(name: 'Completed Task', member:)
    pending_task = service.tasks.create!(name: 'Pending Task', member:)

    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Nguyen Van H',
      priority_status: :high
    )

    order_service.update_column(:completed_at, 5.minutes.ago.change(sec: 0))
    order_service.order_tasks.find_by!(task: completed_task).update!(is_completed: true)

    OrderDeadlineMissJob.new.perform(order_service.id)

    assert_equal false, order_service.order_tasks.find_by!(task: completed_task).reload.is_overdue
    assert_equal true, order_service.order_tasks.find_by!(task: pending_task).reload.is_overdue
    assert_nil order_service.reload.deadline_check_job_id
  end

  private

  def build_service
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
  end

  def build_member(name)
    User.create!(
      email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name:,
      last_login_at: Time.current
    )
  end
end
