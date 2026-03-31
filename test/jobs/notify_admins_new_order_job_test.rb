# frozen_string_literal: true

require 'test_helper'

class NotifyAdminsNewOrderJobTest < ActiveSupport::TestCase
  test 'sends telegram messages to connected admins and assigned members when a new order is created' do
    service = build_service
    connected_admin = build_admin('connected-admin', telegram_chat_id: 123_456_789, telegram_connected_at: Time.current)
    build_admin('plain-admin')
    connected_member = build_member('member-user', telegram_chat_id: 555_555, telegram_connected_at: Time.current)
    second_connected_member = build_member('member-user-2', telegram_chat_id: 666_666, telegram_connected_at: Time.current)
    disconnected_member = build_member('member-user-3')

    first_task = service.tasks.create!(name: 'Task SEO', member: connected_member)
    second_task = service.tasks.create!(name: 'Task Content', member: connected_member)
    third_task = service.tasks.create!(name: 'Task Upload', member: second_connected_member)
    service.tasks.create!(name: 'Task Internal', member: disconnected_member)

    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Tran Van A',
      priority_status: :high,
      google_sheet_link: 'https://docs.google.com/spreadsheets/d/test',
      customer_domain: 'example.com',
      notes: 'Order note'
    )

    deliveries = []
    fake_notifier = Object.new
    fake_notifier.define_singleton_method(:deliver_to) do |user, text:, **|
      deliveries << { user:, text: }
    end

    with_stubbed_constructor(Telegram::Notifier, fake_notifier) do
      NotifyAdminsNewOrderJob.new.perform(order_service.id)
    end

    assert_equal 3, deliveries.size
    assert_equal [ connected_admin, connected_member, second_connected_member ].sort_by(&:id),
                 deliveries.map { |delivery| delivery[:user] }.sort_by(&:id)

    admin_delivery = deliveries.find { |delivery| delivery[:user] == connected_admin }
    assert_includes admin_delivery[:text], order_service.service.name
    assert_includes admin_delivery[:text], order_service.service.partner.name
    assert_includes admin_delivery[:text], order_service.notes

    connected_member_delivery = deliveries.find { |delivery| delivery[:user] == connected_member }
    assert_includes connected_member_delivery[:text], 'Task bạn phụ trách'
    assert_includes connected_member_delivery[:text], "1. <a href="
    assert_includes connected_member_delivery[:text], first_task.name
    assert_includes connected_member_delivery[:text], second_task.name
    assert_includes connected_member_delivery[:text], "#admin_row_order_task_#{first_task.order_tasks.find_by(order_service:).id}"
    assert_not_includes connected_member_delivery[:text], third_task.name

    second_connected_member_delivery = deliveries.find { |delivery| delivery[:user] == second_connected_member }
    assert_includes second_connected_member_delivery[:text], '1. <a href='
    assert_includes second_connected_member_delivery[:text], third_task.name
  end

  private

  def build_service
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
  end

  def build_admin(prefix, telegram_chat_id: nil, telegram_connected_at: nil)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current,
      telegram_chat_id:,
      telegram_connected_at:
    )
  end

  def build_member(prefix, telegram_chat_id: nil, telegram_connected_at: nil)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name: prefix.humanize,
      last_login_at: Time.current,
      telegram_chat_id:,
      telegram_connected_at:
    )
  end
end
