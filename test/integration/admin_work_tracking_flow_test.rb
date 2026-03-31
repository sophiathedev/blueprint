# frozen_string_literal: true

require 'test_helper'

class AdminWorkTrackingFlowTest < ActionDispatch::IntegrationTest
  test 'admin can view work tracking page and filter tasks by member and status' do
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current,
      telegram_chat_id: 301_001,
      telegram_connected_at: Time.current
    )
    first_member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Tracker One',
      last_login_at: Time.current,
      telegram_chat_id: 301_101,
      telegram_connected_at: Time.current
    )
    second_member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Tracker Two',
      last_login_at: Time.current,
      telegram_chat_id: 301_102,
      telegram_connected_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")

    first_service = partner.services.create!(name: "Tracking Service #{SecureRandom.hex(4)}")
    completed_task = first_service.tasks.create!(name: 'Completed Task', member: first_member)
    other_member_task = first_service.tasks.create!(name: 'Pending Task', member: second_member)
    first_order = first_service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC One',
      priority_status: :high
    )
    first_order.order_tasks.find_by!(task: completed_task).update!(is_completed: true)

    second_service = partner.services.create!(name: "Tracking Service #{SecureRandom.hex(4)}")
    overdue_task = second_service.tasks.create!(name: 'Overdue Task', member: first_member)
    second_order = second_service.order_services.create!(
      completed_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'PIC Two',
      priority_status: :medium
    )
    second_order.order_tasks.find_by!(task: overdue_task).update_columns(is_overdue: true, updated_at: Time.current)

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    get admin_work_tracking_path

    assert_response :success
    assert_match 'Theo dõi công việc', response.body
    assert_match first_member.name, response.body
    assert_match second_member.name, response.body
    assert_match completed_task.name, response.body
    assert_match overdue_task.name, response.body
    assert_match other_member_task.name, response.body

    get admin_work_tracking_path(member_id: first_member.id, filter: :overdue)

    assert_response :success
    assert_match overdue_task.name, response.body
    assert_no_match completed_task.name, response.body
    assert_no_match other_member_task.name, response.body
  end

  test 'member cannot access admin work tracking page' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member No Admin Tracking',
      last_login_at: Time.current,
      telegram_chat_id: 301_201,
      telegram_connected_at: Time.current
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    get admin_work_tracking_path

    assert_redirected_to root_path
  end
end
