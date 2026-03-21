# frozen_string_literal: true

require 'test_helper'

class OrderServiceTest < ActiveSupport::TestCase
  test 'casts date-only completed_at to beginning of day' do
    service = build_service

    order_service = OrderService.create!(
      service:,
      completed_at: '2026-03-22',
      partner_assignee_name: 'Nguyen Van A',
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
      priority_status: :high
    )

    order_service.destroy

    assert Service.exists?(service.id)
    assert_equal service.id, service.reload.id
  end

  test 'requires completed_at partner_assignee_name and priority_status but allows blank notes' do
    service = build_service

    order_service = OrderService.new(service:, notes: '')

    assert_not order_service.valid?
    assert_includes order_service.errors[:completed_at], 'không được để trống'
    assert_includes order_service.errors[:partner_assignee_name], 'không được để trống'
    assert_includes order_service.errors[:priority_status], 'không được để trống'
    assert_empty order_service.errors[:notes]
  end

  test 'requires completed_at to be from now onward' do
    service = build_service

    order_service = OrderService.new(
      service:,
      completed_at: 1.minute.ago.change(sec: 0),
      partner_assignee_name: 'Nguyen Van D',
      priority_status: :low
    )

    assert_not order_service.valid?
    assert_includes order_service.errors[:completed_at], 'phải từ thời điểm hiện tại trở đi'
  end

  private

  def build_service
    partner = Partner.create!(name: "Partner #{SecureRandom.hex(4)}")
    partner.services.create!(name: "Service #{SecureRandom.hex(4)}")
  end
end
