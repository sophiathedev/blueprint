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
      customer_domain: 'task-member.example.com',
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
      customer_domain: 'complete-member.example.com',
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

  test 'member can search assigned order tasks by customer domain' do
    member = build_member('Search Domain Member')
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    alpha_service = partner.services.create!(name: "Alpha Service #{SecureRandom.hex(4)}")
    beta_service = partner.services.create!(name: "Beta Service #{SecureRandom.hex(4)}")
    alpha_task = alpha_service.tasks.create!(name: 'Alpha Task', member:)
    beta_task = beta_service.tasks.create!(name: 'Beta Task', member:)

    alpha_service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Tran Van Search Alpha',
      priority_status: :medium,
      google_sheet_link: 'https://docs.google.com/spreadsheets/d/member-task-alpha',
      customer_domain: 'alpha-task.example.com'
    )
    beta_service.order_services.create!(
      completed_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'Tran Van Search Beta',
      priority_status: :high,
      google_sheet_link: 'https://docs.google.com/spreadsheets/d/member-task-beta',
      customer_domain: 'beta-task.example.com'
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    get member_order_tasks_path(q: 'alpha-task.example.com')

    assert_response :success
    assert_match alpha_task.name, response.body
    assert_match 'alpha-task.example.com', response.body
    assert_no_match beta_task.name, response.body
    assert_no_match 'beta-task.example.com', response.body
  end

  test 'member can filter assigned order tasks by deadline bucket' do
    freeze_time do
      member = build_member('Deadline Filter Member')
      partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
      today_service = partner.services.create!(name: "Today Service #{SecureRandom.hex(4)}")
      tomorrow_service = partner.services.create!(name: "Tomorrow Service #{SecureRandom.hex(4)}")
      today_task = today_service.tasks.create!(name: 'Task hôm nay', member:)
      tomorrow_task = tomorrow_service.tasks.create!(name: 'Task ngày mai', member:)

      today_service.order_services.create!(
        completed_at: Time.current.change(hour: 18, min: 0, sec: 0),
        partner_assignee_name: '',
        customer_domain: 'today-task-filter.example.com',
        priority_status: :high
      )
      tomorrow_service.order_services.create!(
        completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
        partner_assignee_name: '',
        customer_domain: 'tomorrow-task-filter.example.com',
        priority_status: :medium
      )

      post login_path, params: { user: { email: member.email, password: 'Password1!' } }
      get member_order_tasks_path(deadline: 'today')

      assert_response :success
      assert_match 'Lọc nhanh theo deadline', response.body
      assert_match today_task.name, response.body
      assert_no_match tomorrow_task.name, response.body
    end
  end

  test 'member is redirected to member task page when opening admin task management url' do
    member = build_member('Redirect Member')
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    get admin_partner_service_tasks_path(partner, service)

    assert_redirected_to member_order_tasks_path
    follow_redirect!
    assert_response :success
    assert_match 'Quản lý Task', response.body
    assert_no_match 'Bạn không có quyền truy cập khu vực quản trị.', response.body
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
