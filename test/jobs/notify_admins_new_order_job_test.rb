# frozen_string_literal: true

require 'test_helper'

class NotifyAdminsNewOrderJobTest < ActiveSupport::TestCase
  test 'sends telegram message to telegram-connected admins when a new order is created' do
    service = build_service
    connected_admin = build_admin('connected-admin', telegram_chat_id: 123_456_789, telegram_connected_at: Time.current)
    build_admin('plain-admin')
    build_member('member-user', telegram_chat_id: 555_555, telegram_connected_at: Time.current)

    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Tran Van A',
      priority_status: :high,
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

    assert_equal 1, deliveries.size
    assert_equal connected_admin, deliveries.first[:user]
    assert_includes deliveries.first[:text], order_service.service.name
    assert_includes deliveries.first[:text], order_service.service.partner.name
    assert_includes deliveries.first[:text], order_service.notes
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
