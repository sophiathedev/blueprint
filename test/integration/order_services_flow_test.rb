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
      last_login_at: Time.current,
      telegram_chat_id: 100_001,
      telegram_connected_at: Time.current
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
          google_sheet_link: '',
          customer_domain: 'sidebar-order.example.com',
          priority_status: 'high',
          detailed_notes: 'Tạo từ sidebar'
        }
      }
    end

    order_service = OrderService.order(:id).last

    assert_redirected_to root_path
    assert_equal service.id, order_service.service_id
    assert_equal 'Nguyen Van Sidebar', order_service.partner_assignee_name
    assert_equal '', order_service.google_sheet_link
    assert_equal 'sidebar-order.example.com', order_service.customer_domain
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
      last_login_at: Time.current,
      telegram_chat_id: 100_002,
      telegram_connected_at: Time.current
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
          google_sheet_link: '',
          customer_domain: 'service-order.example.com',
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
    assert_equal '', order_service.google_sheet_link
    assert_equal 'service-order.example.com', order_service.customer_domain
    assert_equal 'urgent', order_service.priority_status
    assert_equal 'Ghi chú test rất dài', order_service.notes
    assert_equal future_time, order_service.completed_at
  end

  test 'order service form rejects only required fields and allows blank optional fields' do
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
          google_sheet_link: '',
          customer_domain: '',
          priority_status: '',
          detailed_notes: ''
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match 'Vui lòng chọn thời gian hoàn thành.', response.body
    assert_match 'Domain Khách Hàng không được để trống', response.body
    assert_match 'Trạng thái ưu tiên không được để trống', response.body
    assert_no_match 'Tên nhân sự của đối tác không được để trống', response.body
    assert_no_match 'Link Google Sheet không được để trống', response.body
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
          google_sheet_link: '',
          customer_domain: 'past-order.example.com',
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
          partner_assignee_name: '',
          google_sheet_link: '',
          customer_domain: 'optional-order.example.com',
          priority_status: 'low',
          detailed_notes: ''
        }
      }
    end

    assert_redirected_to new_admin_partner_service_task_path(partner, service)
    order_service = OrderService.order(:id).last
    assert_equal '', order_service.partner_assignee_name
    assert_equal '', order_service.google_sheet_link
    assert_equal 'optional-order.example.com', order_service.customer_domain
    assert_equal '', order_service.notes
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
      customer_domain: 'order-detail.example.com',
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
      customer_domain: 'edit-order.example.com',
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
        google_sheet_link: '',
        customer_domain: 'edit-order-updated.example.com',
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
    assert_equal '', order_service.google_sheet_link
    assert_equal 'edit-order-updated.example.com', order_service.customer_domain
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
      customer_domain: 'visible-dashboard.example.com',
      priority_status: :high
    )

    hidden_partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    hidden_service = hidden_partner.services.create!(name: "Hidden Service #{SecureRandom.hex(4)}")
    hidden_service.tasks.create!(name: 'Hidden Task', member: another_member)
    hidden_service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'PIC Hidden',
      customer_domain: 'hidden-dashboard.example.com',
      priority_status: :medium
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    get root_path

    assert_response :success
    assert_match visible_service.name, response.body
    assert_no_match hidden_service.name, response.body
  end

  test 'dashboard can filter orders by deadline bucket to prioritize soonest work' do
    freeze_time do
      admin = User.create!(
        email: "admin-#{SecureRandom.hex(4)}@example.com",
        password: 'Password1!',
        password_confirmation: 'Password1!',
        role: :admin,
        last_login_at: Time.current
      )
      partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
      today_service = partner.services.create!(name: "Today Service #{SecureRandom.hex(4)}")
      tomorrow_service = partner.services.create!(name: "Tomorrow Service #{SecureRandom.hex(4)}")

      today_service.order_services.create!(
        completed_at: Time.current.change(hour: 18, min: 0, sec: 0),
        partner_assignee_name: '',
        customer_domain: 'today-filter.example.com',
        priority_status: :high
      )
      tomorrow_service.order_services.create!(
        completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
        partner_assignee_name: '',
        customer_domain: 'tomorrow-filter.example.com',
        priority_status: :medium
      )

      post login_path, params: { user: { email: admin.email, password: 'Password1!' } }
      get root_path(deadline: 'today')

      assert_response :success
      assert_match 'Lọc nhanh theo hạn hoàn thành', response.body
      assert_match today_service.name, response.body
      assert_no_match tomorrow_service.name, response.body
    end
  end

  test 'admin can search dashboard orders by service, partner, or customer domain' do
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
    alpha_partner = Partner.create!(name: "Alpha Partner #{SecureRandom.hex(4)}")
    beta_partner = Partner.create!(name: "Beta Partner #{SecureRandom.hex(4)}")
    alpha_service = alpha_partner.services.create!(name: "Alpha Service #{SecureRandom.hex(4)}")
    beta_service = beta_partner.services.create!(name: "Beta Service #{SecureRandom.hex(4)}")

    alpha_service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Alpha',
      priority_status: :high,
      google_sheet_link: 'https://docs.google.com/spreadsheets/d/alpha',
      customer_domain: 'alpha.example.com'
    )
    beta_service.order_services.create!(
      completed_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'PIC Beta',
      priority_status: :medium,
      google_sheet_link: 'https://docs.google.com/spreadsheets/d/beta',
      customer_domain: 'beta.example.com'
    )

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    get root_path(q: alpha_service.name)

    assert_response :success
    assert_match alpha_service.name, response.body
    assert_no_match beta_service.name, response.body

    get root_path(q: alpha_partner.name)

    assert_response :success
    assert_match alpha_partner.name, response.body
    assert_no_match beta_partner.name, response.body

    get root_path(q: 'alpha.example.com')

    assert_response :success
    assert_match alpha_service.name, response.body
    assert_match 'alpha.example.com', response.body
    assert_no_match beta_service.name, response.body
    assert_no_match 'beta.example.com', response.body
  end

  test 'member can search their dashboard orders by service, partner, or customer domain' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Search Dashboard',
      last_login_at: Time.current
    )
    alpha_partner = Partner.create!(name: "Visible Partner #{SecureRandom.hex(4)}")
    beta_partner = Partner.create!(name: "Hidden Partner #{SecureRandom.hex(4)}")
    alpha_service = alpha_partner.services.create!(name: "Visible Search Service #{SecureRandom.hex(4)}")
    beta_service = beta_partner.services.create!(name: "Hidden Search Service #{SecureRandom.hex(4)}")

    alpha_service.tasks.create!(name: 'Alpha Task', member:)
    beta_service.tasks.create!(name: 'Beta Task', member:)

    alpha_service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 11, min: 0, sec: 0),
      partner_assignee_name: 'PIC Alpha Member',
      priority_status: :high,
      google_sheet_link: 'https://docs.google.com/spreadsheets/d/member-alpha',
      customer_domain: 'member-alpha.example.com'
    )
    beta_service.order_services.create!(
      completed_at: 2.days.from_now.change(hour: 14, min: 0, sec: 0),
      partner_assignee_name: 'PIC Beta Member',
      priority_status: :medium,
      google_sheet_link: 'https://docs.google.com/spreadsheets/d/member-beta',
      customer_domain: 'member-beta.example.com'
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    get root_path(q: alpha_service.name)

    assert_response :success
    assert_match alpha_service.name, response.body
    assert_no_match beta_service.name, response.body

    get root_path(q: alpha_partner.name)

    assert_response :success
    assert_match alpha_partner.name, response.body
    assert_no_match beta_partner.name, response.body

    get root_path(q: 'member-alpha.example.com')

    assert_response :success
    assert_match alpha_service.name, response.body
    assert_match 'member-alpha.example.com', response.body
    assert_no_match beta_service.name, response.body
    assert_no_match 'member-beta.example.com', response.body
  end

  test 'dashboard keeps overdue orders visible until an admin deletes them' do
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current,
      telegram_chat_id: 100_301,
      telegram_connected_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Overdue Service #{SecureRandom.hex(4)}")
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Overdue',
      customer_domain: 'overdue-dashboard.example.com',
      priority_status: :urgent
    )
    order_service.update_column(:completed_at, 1.day.ago.change(sec: 0))

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }
    get root_path

    assert_response :success
    assert_match service.name, response.body
    assert_match 'Danh sách order đang quản lý', response.body
  end

  test 'admin can bulk delete selected orders and their order tasks from dashboard' do
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current,
      telegram_chat_id: 100_302,
      telegram_connected_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Bulk Delete Service #{SecureRandom.hex(4)}")
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Bulk Delete Member',
      last_login_at: Time.current,
      telegram_chat_id: 200_302,
      telegram_connected_at: Time.current
    )
    task = service.tasks.create!(name: 'Bulk Delete Task', member:)
    first_order = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 8, min: 0, sec: 0),
      partner_assignee_name: 'PIC One',
      customer_domain: 'bulk-delete-one.example.com',
      priority_status: :high
    )
    second_order = service.order_services.create!(
      completed_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'PIC Two',
      customer_domain: 'bulk-delete-two.example.com',
      priority_status: :medium
    )
    first_order_task = first_order.order_tasks.find_by!(task:)
    second_order_task = second_order.order_tasks.find_by!(task:)

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    assert_difference('OrderService.count', -2) do
      assert_difference('OrderTask.count', -2) do
        delete bulk_destroy_admin_order_services_path, params: {
          order_service_ids: [first_order.id, second_order.id]
        }
      end
    end

    assert_redirected_to root_path
    assert_not OrderService.exists?(first_order.id)
    assert_not OrderService.exists?(second_order.id)
    assert_not_nil OrderService.with_deleted.find(first_order.id).deleted_at
    assert_not_nil OrderService.with_deleted.find(second_order.id).deleted_at
    assert_not OrderTask.exists?(first_order_task.id)
    assert_not OrderTask.exists?(second_order_task.id)
    assert_not_nil OrderTask.with_deleted.find(first_order_task.id).deleted_at
    assert_not_nil OrderTask.with_deleted.find(second_order_task.id).deleted_at
    assert Task.exists?(task.id)
  end

  test 'member cannot bulk delete orders from dashboard' do
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member No Delete',
      last_login_at: Time.current,
      telegram_chat_id: 200_303,
      telegram_connected_at: Time.current
    )
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    service = partner.services.create!(name: "Protected Service #{SecureRandom.hex(4)}")
    service.tasks.create!(name: 'Protected Task', member:)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'PIC Protected',
      customer_domain: 'protected-dashboard.example.com',
      priority_status: :high
    )

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    assert_no_difference('OrderService.count') do
      delete bulk_destroy_admin_order_services_path, params: {
        order_service_ids: [order_service.id]
      }
    end

    assert_redirected_to root_path
    assert OrderService.exists?(order_service.id)
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
      customer_domain: 'member-viewer.example.com',
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
      customer_domain: 'highlight-dashboard.example.com',
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
      customer_domain: 'member-update.example.com',
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
      customer_domain: 'completed-task.example.com',
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
