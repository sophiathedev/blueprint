# frozen_string_literal: true

require 'test_helper'

class OrderServicesFlowTest < ActionDispatch::IntegrationTest
  test 'admin can create an order service from the global order page' do
    future_time = 1.day.from_now.change(hour: 14, min: 0, sec: 0)
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    get new_admin_order_service_path
    assert_response :success
    assert_match 'Đặt dịch vụ mới', response.body
    assert_match service.name, response.body
    assert_match partner.name, response.body

    assert_difference('OrderService.count', 1) do
      post admin_order_services_path, params: {
        order_service: {
          service_id: service.id,
          completion_date: future_time.strftime('%Y-%m-%d'),
          completion_date_enabled: '1',
          completion_time_enabled: '1',
          completion_hour: future_time.strftime('%H'),
          completion_minute: future_time.strftime('%M'),
          partner_assignee_name: 'Nguyen Van Sidebar',
          priority_status: 'high',
          detailed_notes: 'Tạo từ sidebar'
        }
      }
    end

    order_service = OrderService.order(:id).last

    assert_redirected_to root_path
    assert_equal service.id, order_service.service_id
    assert_equal 'Nguyen Van Sidebar', order_service.partner_assignee_name
    assert_equal 'high', order_service.priority_status
    assert_equal 'Tạo từ sidebar', order_service.notes
    assert_equal future_time, order_service.completed_at
  end

  test 'admin can create an order service from the order page' do
    future_time = 1.day.from_now.change(hour: 9, min: 30, sec: 0)
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    assert_redirected_to root_path
    get new_admin_partner_service_task_path(partner, service)
    assert_response :success

    assert_difference('OrderService.count', 1) do
      post admin_partner_service_tasks_path(partner, service), params: {
        order_request: {
          completion_date: future_time.strftime('%Y-%m-%d'),
          completion_date_enabled: '1',
          completion_time_enabled: '1',
          completion_hour: future_time.strftime('%H'),
          completion_minute: future_time.strftime('%M'),
          partner_assignee_name: 'Nguyen Van A',
          priority_status: 'urgent',
          detailed_notes: 'Ghi chú test rất dài'
        }
      }
    end

    order_service = OrderService.order(:id).last

    assert_redirected_to root_path
    follow_redirect!
    assert_match 'Đặt dịch vụ thành công.', response.body
    assert_response :success
    assert_match 'Danh sách order hiện tại', response.body
    assert_match service.name, response.body
    assert_match partner.name, response.body

    assert_equal service.id, order_service.service_id
    assert_equal 'Nguyen Van A', order_service.partner_assignee_name
    assert_equal 'urgent', order_service.priority_status
    assert_equal 'Ghi chú test rất dài', order_service.notes
    assert_equal future_time, order_service.completed_at
  end

  test 'order service form rejects missing required fields and allows blank notes' do
    future_time = 1.day.from_now.change(hour: 10, min: 15, sec: 0)
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    assert_no_difference('OrderService.count') do
      post admin_partner_service_tasks_path(partner, service), params: {
        order_request: {
          completion_date: '',
          completion_date_enabled: '0',
          completion_time_enabled: '0',
          completion_hour: '',
          completion_minute: '',
          partner_assignee_name: '',
          priority_status: '',
          detailed_notes: ''
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match 'Vui lòng chọn thời gian hoàn thành.', response.body
    assert_match 'Tên nhân sự của đối tác không được để trống', response.body
    assert_match 'Trạng thái ưu tiên không được để trống', response.body
    assert_no_match 'Completed at không được để trống', response.body

    assert_no_difference('OrderService.count') do
      post admin_partner_service_tasks_path(partner, service), params: {
        order_request: {
          completion_date: 1.day.ago.strftime('%Y-%m-%d'),
          completion_date_enabled: '1',
          completion_time_enabled: '1',
          completion_hour: '09',
          completion_minute: '00',
          partner_assignee_name: 'Nguyen Van C',
          priority_status: 'low',
          detailed_notes: ''
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match 'Vui lòng chọn thời gian hoàn thành từ hiện tại trở đi.', response.body

    assert_difference('OrderService.count', 1) do
      post admin_partner_service_tasks_path(partner, service), params: {
        order_request: {
          completion_date: future_time.strftime('%Y-%m-%d'),
          completion_date_enabled: '1',
          completion_time_enabled: '1',
          completion_hour: future_time.strftime('%H'),
          completion_minute: future_time.strftime('%M'),
          partner_assignee_name: 'Nguyen Van C',
          priority_status: 'low',
          detailed_notes: ''
        }
      }
    end

    assert_redirected_to new_admin_partner_service_task_path(partner, service)
    assert_equal '', OrderService.order(:id).last.notes
  end

  test 'admin can view order service details page' do
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Test',
      last_login_at: Time.current
    )
    service.tasks.create!(name: 'Task order detail', member:)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 8, min: 0, sec: 0),
      partner_assignee_name: 'Tran Thi B',
      priority_status: :high,
      notes: 'Can xu ly trong buoi sang'
    )

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }
    get admin_order_service_path(order_service)

    assert_response :success
    assert_match service.name, response.body
    assert_match partner.name, response.body
    assert_match 'Tran Thi B', response.body
    assert_match 'Can xu ly trong buoi sang', response.body
    assert_match 'Trạng thái task', response.body
    assert_match 'Task order detail', response.body
    assert_match 'Chưa hoàn thành', response.body
  end

  test 'admin can edit an order service' do
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 8, min: 0, sec: 0),
      partner_assignee_name: 'Tran Thi C',
      priority_status: :medium,
      notes: 'Noi dung cu'
    )

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }
    get edit_admin_order_service_path(order_service)

    assert_response :success
    assert_match 'Chỉnh sửa order', response.body

    patch admin_order_service_path(order_service), params: {
      order_service: {
        completion_date: 2.days.from_now.strftime('%Y-%m-%d'),
        completion_date_enabled: '1',
        completion_time_enabled: '1',
        completion_hour: '10',
        completion_minute: '30',
        partner_assignee_name: 'Tran Thi C Updated',
        priority_status: 'urgent',
        detailed_notes: 'Noi dung moi'
      }
    }

    assert_redirected_to admin_order_service_path(order_service)
    follow_redirect!
    assert_match 'Cập nhật order thành công.', response.body
    assert_match 'Tran Thi C Updated', response.body
    assert_match 'Noi dung moi', response.body

    order_service.reload
    assert_equal 'Tran Thi C Updated', order_service.partner_assignee_name
    assert_equal 'urgent', order_service.priority_status
    assert_equal 'Noi dung moi', order_service.notes
    assert_equal 2.days.from_now.strftime('%Y-%m-%d'), order_service.completed_at.strftime('%Y-%m-%d')
    assert_equal '10:30', order_service.completed_at.strftime('%H:%M')
  end

  test 'member dashboard only shows orders that include their assigned tasks' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Dashboard',
      last_login_at: Time.current
    )
    another_member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Another Member',
      last_login_at: Time.current
    )

    visible_partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    visible_service = visible_partner.services.create!(name: "Visible Service #{SecureRandom.hex(4)}")
    visible_service.tasks.create!(name: 'Visible Task', member:)
    visible_service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Visible',
      priority_status: :high
    )

    hidden_partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    hidden_service = hidden_partner.services.create!(name: "Hidden Service #{SecureRandom.hex(4)}")
    hidden_service.tasks.create!(name: 'Hidden Task', member: another_member)
    hidden_service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'PIC Hidden',
      priority_status: :medium
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    get root_path

    assert_response :success
    assert_match visible_service.name, response.body
    assert_no_match hidden_service.name, response.body
  end

  test 'member can view visible order service details but cannot edit it' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Viewer',
      last_login_at: Time.current
    )
    another_member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Hidden Member',
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    service.tasks.create!(name: 'Visible Task', member:)
    service.tasks.create!(name: 'Hidden Task', member: another_member)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Test',
      priority_status: :urgent,
      notes: 'Member can read this order'
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    get admin_order_service_path(order_service)
    assert_response :success
    assert_match service.name, response.body
    assert_match 'PIC Test', response.body
    assert_match 'Member can read this order', response.body
    assert_match 'Visible Task', response.body
    assert_no_match 'Hidden Task', response.body
    assert_no_match 'Sửa order', response.body
    assert_no_match 'Đặt dịch vụ', response.body

    get edit_admin_order_service_path(order_service)
    assert_redirected_to root_path
  end

  test 'member sees their task highlighted when opening order service from dashboard' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Highlight',
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    service.tasks.create!(name: 'Highlighted Task', member:)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Highlight',
      priority_status: :high
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    get admin_order_service_path(order_service, source: :dashboard)
    assert_response :success
    assert_match 'Task của bạn', response.body

    get admin_order_service_path(order_service)
    assert_response :success
    assert_no_match 'Task của bạn', response.body
  end

  test 'member can update their visible order task from order service page' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Update Task',
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    task = service.tasks.create!(name: 'Updatable Task', member:)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Update',
      priority_status: :high
    )
    order_task = order_service.order_tasks.find_by!(task:)

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    patch admin_order_service_order_task_path(order_service, order_task), params: {
      source: 'dashboard',
      order_task: { is_completed: '1' }
    }

    assert_redirected_to admin_order_service_path(order_service, source: 'dashboard')
    order_task.reload
    assert order_task.is_completed?
    assert_not_nil order_task.mark_completed_at
  end

  test 'member cannot uncheck a completed order task but admin can' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Completed Task',
      last_login_at: Time.current
    )
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
    task = service.tasks.create!(name: 'Completed Task', member:)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Completed',
      priority_status: :high
    )
    order_task = order_service.order_tasks.find_by!(task:)
    order_task.update!(is_completed: true)

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    patch admin_order_service_order_task_path(order_service, order_task), params: {
      order_task: { is_completed: '0' }
    }

    assert_redirected_to admin_order_service_path(order_service)
    order_task.reload
    assert order_task.is_completed?

    delete logout_path
    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }
    patch admin_order_service_order_task_path(order_service, order_task), params: {
      order_task: { is_completed: '0' }
    }

    assert_redirected_to admin_order_service_path(order_service)
    order_task.reload
    assert_not order_task.is_completed?
    assert_nil order_task.mark_completed_at
  end
end
