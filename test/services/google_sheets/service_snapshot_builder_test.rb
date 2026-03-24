# frozen_string_literal: true

require 'test_helper'

class GoogleSheetsServiceSnapshotBuilderTest < ActiveSupport::TestCase
  test 'builds order rows only for placed orders' do
    member = build_member('Snapshot Member')
    partner = Partner.create!(name: 'Partner One')
    service = partner.services.create!(name: 'Service One')
    task = service.tasks.create!(name: 'Task Alpha', member:)
    order_service = service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Tran Van A',
      priority_status: :high,
      notes: 'Need follow-up'
    )
    order_task = order_service.order_tasks.find_by!(task:)

    snapshot = GoogleSheets::ServiceSnapshotBuilder.new(service)

    assert_equal GoogleSheets::ServiceSnapshotBuilder::ORDER_HEADERS, snapshot.order_rows.first
    assert_equal true, snapshot.has_order_rows?
    refute_includes snapshot.order_rows.first, 'order_task_id'
    refute_includes snapshot.order_rows.flatten, order_task.id
    assert_includes snapshot.order_rows.first, 'Đối tác'
    assert_includes snapshot.order_rows.first, 'Đã hoàn thành'
    assert_includes snapshot.order_rows.flatten, 'Cao'
    assert_includes snapshot.order_rows.flatten, 'Need follow-up'
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
