# frozen_string_literal: true

require 'test_helper'

class OrderServiceTest < ActiveSupport::TestCase
  test 'casts date-only completed_at to beginning of day' do
    service = build_service

    order_service = OrderService.create!(
      service:,
      completed_at: '2026-03-22',
      partner_assignee_name: 'Nguyen Van A',
      customer_domain: 'casts-date.example.com',
      priority_status: :urgent,
      notes: 'Ghi chú rất dài'
    )

    assert_equal Time.zone.local(2026, 3, 22, 0, 0, 0), order_service.completed_at
  end

  test 'destroying an order service does not affect its service' do
    service = build_service
    order_service = OrderService.create!(
      service:,
      completed_at: Time.zone.local(2026, 3, 22, 9, 30, 0),
      partner_assignee_name: 'Nguyen Van B',
      customer_domain: 'destroy-service.example.com',
      priority_status: :high
    )

    order_service.destroy

    assert Service.exists?(service.id)
    assert_equal service.id, service.reload.id
  end

  test 'destroying an order service soft deletes its order tasks' do
    service = build_service
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Cascade',
      last_login_at: Time.current
    )
    task = service.tasks.create!(name: 'Task Cascade', member:)
    order_service = OrderService.create!(
      service:,
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Nguyen Van Cascade',
      customer_domain: 'cascade.example.com',
      priority_status: :high
    )
    order_task = order_service.order_tasks.find_by!(task:)

    assert_difference('OrderTask.count', -1) do
      order_service.destroy
    end

    assert Task.exists?(task.id)
    assert_not OrderTask.exists?(order_task.id)
    assert_not_nil OrderTask.with_deleted.find(order_task.id).deleted_at
  end

  test 'requires completed_at customer_domain and priority_status but allows blank optional fields' do
    service = build_service

    order_service = OrderService.new(service:, notes: '')

    assert_not order_service.valid?
    assert_includes order_service.errors[:completed_at], 'không được để trống'
    assert_includes order_service.errors[:customer_domain], 'không được để trống'
    assert_includes order_service.errors[:priority_status], 'không được để trống'
    assert_empty order_service.errors[:notes]
    assert_empty order_service.errors[:partner_assignee_name]
    assert_empty order_service.errors[:google_sheet_link]
  end

  test 'allows blank partner_assignee_name and google_sheet_link' do
    service = build_service

    order_service = OrderService.new(
      service:,
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: '',
      google_sheet_link: '',
      customer_domain: 'optional-fields.example.com',
      priority_status: :medium
    )

    assert order_service.valid?
  end

  test 'requires completed_at to be from now onward' do
    service = build_service

    order_service = OrderService.new(
      service:,
      completed_at: 1.minute.ago.change(sec: 0),
      partner_assignee_name: 'Nguyen Van D',
      customer_domain: 'future-only.example.com',
      priority_status: :low
    )

    assert_not order_service.valid?
    assert_includes order_service.errors[:completed_at], 'phải từ thời điểm hiện tại trở đi'
  end

  test 'creates order tasks from existing service tasks when order service is created' do
    service = build_service
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Test',
      last_login_at: Time.current
    )
    task = service.tasks.create!(name: 'Task A', member:)

    order_service = OrderService.create!(
      service:,
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Nguyen Van E',
      customer_domain: 'create-order-tasks.example.com',
      priority_status: :medium
    )

    assert_equal [ task.id ], order_service.order_tasks.pluck(:task_id)
    assert_equal false, order_service.order_tasks.first.is_completed
    assert_nil order_service.order_tasks.first.mark_completed_at
    assert_equal false, order_service.order_tasks.first.is_overdue
  end

  test 'schedules a sidekiq deadline job when order service is created' do
    service = build_service
    deadline = 1.day.from_now.change(hour: 11, min: 45, sec: 0)

    order_service = OrderService.create!(
      service:,
      completed_at: deadline,
      partner_assignee_name: 'Nguyen Van G',
      customer_domain: 'deadline-job.example.com',
      priority_status: :urgent
    )

    assert_equal 1, OrderDeadlineMissJob.jobs.size

    scheduled_job = OrderDeadlineMissJob.jobs.last

    assert_equal [ order_service.id ], scheduled_job['args']
    assert_in_delta deadline.to_f, scheduled_job['at'], 1.0
    assert_equal scheduled_job['jid'], order_service.reload.deadline_check_job_id
  end

  test 'enqueues a telegram notification job for admins when order service is created' do
    service = build_service

    order_service = OrderService.create!(
      service:,
      completed_at: 1.day.from_now.change(hour: 11, min: 45, sec: 0),
      partner_assignee_name: 'Nguyen Van H',
      customer_domain: 'notify-admins.example.com',
      priority_status: :urgent
    )

    assert_equal 1, NotifyAdminsNewOrderJob.jobs.size
    assert_equal [ order_service.id ], NotifyAdminsNewOrderJob.jobs.last['args']
  end

  test 'destroying an order task does not affect its task' do
    service = build_service
    member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: 'Member Test',
      last_login_at: Time.current
    )
    task = service.tasks.create!(name: 'Task B', member:)
    order_service = OrderService.create!(
      service:,
      completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'Nguyen Van F',
      customer_domain: 'destroy-order-task.example.com',
      priority_status: :high
    )

    order_task = order_service.order_tasks.find_by!(task:)
    order_task.destroy

    assert Task.exists?(task.id)
  end

  private

  def build_service
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
  end
end
