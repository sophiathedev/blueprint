# frozen_string_literal: true

require 'test_helper'

class OrderServicesFlowTest < ActionDispatch::IntegrationTest
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

    assert_redirected_to new_admin_partner_service_task_path(partner, service)
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
end
