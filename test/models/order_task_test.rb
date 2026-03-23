# frozen_string_literal: true

require 'test_helper'

class OrderTaskTest < ActiveSupport::TestCase
  test 'visible_to returns only tasks assigned to the current member' do
    service = build_service
    visible_member = build_member('Visible Member')
    hidden_member = build_member('Hidden Member')

    visible_task = service.tasks.create!(name: 'Visible Task', member: visible_member)
    hidden_task = service.tasks.create!(name: 'Hidden Task', member: hidden_member)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Nguyen Van A',
      priority_status: :high
    )

    assert_equal [visible_task.id], OrderTask.visible_to(visible_member).pluck(:task_id)
    assert_equal [hidden_task.id], OrderTask.visible_to(hidden_member).pluck(:task_id)
    assert_equal order_service.order_tasks.pluck(:order_service_id).uniq, OrderTask.for_user_order_services(visible_member).pluck(:order_service_id)
  end

  test 'visible_to returns all tasks for admin users' do
    service = build_service
    member = build_member('Assigned Member')
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )

    service.tasks.create!(name: 'Task A', member:)
    service.tasks.create!(name: 'Task B', member:)
    service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'Nguyen Van B',
      priority_status: :medium
    )

    assert_equal OrderTask.count, OrderTask.visible_to(admin).count
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
