# frozen_string_literal: true

require 'test_helper'

class MemberOrderTasksFlowTest < ActionDispatch::IntegrationTest
  test 'member can view assigned order tasks from sidebar page' do
    member = build_member('Task Member')
    other_member = build_member('Other Member')
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    own_task = service.tasks.create!(name: 'Task của tôi', member:)
    service.tasks.create!(name: 'Task người khác', member: other_member)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Tran Van A',
      priority_status: :medium
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    get member_order_tasks_path

    assert_response :success
    assert_match 'Quản lý Task', response.body
    assert_match own_task.name, response.body
    assert_match service.name, response.body
    assert_match partner.name, response.body
    assert_no_match 'Task người khác', response.body
    assert_match admin_order_service_path(order_service, source: :member_tasks), response.body
  end

  test 'member can mark assigned order task complete from task management page' do
    member = build_member('Complete Member')
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    task = service.tasks.create!(name: 'Task cần hoàn thành', member:)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'Le Thi B',
      priority_status: :high
    )
    order_task = order_service.order_tasks.find_by!(task:)

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    patch admin_order_service_order_task_path(order_service, order_task), params: {
      source: 'member_tasks',
      order_task: { is_completed: '1' }
    }

    assert_redirected_to member_order_tasks_path
    assert_equal true, order_task.reload.is_completed?
    assert_not_nil order_task.mark_completed_at
  end

  private

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
