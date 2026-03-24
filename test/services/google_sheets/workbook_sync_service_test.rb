# frozen_string_literal: true

require 'test_helper'

class GoogleSheetsWorkbookSyncServiceTest < ActiveSupport::TestCase
  test 'syncs only order tabs and removes stale managed tabs' do
    member = build_member('Workbook Member')
    partner = Partner.create!(name: 'Partner A')
    service = partner.services.create!(name: 'Service A')
    task = service.tasks.create!(name: 'Task A', member:)
    service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
      partner_assignee_name: 'Tran Van A',
      priority_status: :medium
    ).order_tasks.find_by!(task:)

    setting = AppSetting.create!(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: 'spreadsheet-id',
      google_sheets_tab_prefix: 'Blueprint',
      google_sheets_sync_interval_value: 5,
      google_sheets_sync_interval_unit: :minutes
    )
    client = FakeGoogleSheetsClient.new(
      sheets: {
        'Blueprint | TPL - Old Partner - Old Service | 999' => {
          'sheetId' => 12,
          'gridProperties' => { 'rowCount' => 1000, 'columnCount' => 26 }
        },
        'Unmanaged Sheet' => 20
      }
    )

    GoogleSheets::WorkbookSyncService.new(setting:, client:).call

    all_batch_requests = client.batch_updates.flatten
    assert_operator client.batch_updates.size, :>=, 2
    assert_equal 1, client.updated_spreadsheet_titles.size
    assert_equal 1, all_batch_requests.count { |request| request.key?(:addSheet) }
    assert all_batch_requests.any? { |request| request.key?(:deleteSheet) }
    assert all_batch_requests.any? { |request| request.key?(:updateSheetProperties) }
    assert_equal 1, client.cleared_ranges.size
    assert_equal 1, client.updated_ranges.size
    assert client.updated_values.flatten.include?('Task A')
  end

  test 'creates spreadsheet automatically when spreadsheet id is blank' do
    member = build_member('Auto Create Member')
    partner = Partner.create!(name: 'Partner B')
    service = partner.services.create!(name: 'Service B')
    task = service.tasks.create!(name: 'Task B', member:)
    service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0),
      partner_assignee_name: 'Le Thi B',
      priority_status: :high
    ).order_tasks.find_by!(task:)

    setting = AppSetting.create!(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: nil,
      google_sheets_tab_prefix: 'Blueprint',
      google_sheets_sync_interval_value: 5,
      google_sheets_sync_interval_unit: :minutes
    )
    client = FakeGoogleSheetsClient.new(sheets: {})

    GoogleSheets::WorkbookSyncService.new(setting:, client:).call

    assert_equal 'generated-spreadsheet-id', setting.reload.google_sheets_spreadsheet_id
    assert_match(/\Ablueprint-\d{2}-\d{2}-\d{2}-\d{8}\z/, client.created_spreadsheet_titles.first)
    assert_equal 1, client.updated_spreadsheet_titles.size
    assert_equal 1, client.updated_ranges.size
  end

  test 'recreates spreadsheet when current spreadsheet id no longer exists' do
    member = build_member('Recreate Member')
    partner = Partner.create!(name: 'Partner C')
    service = partner.services.create!(name: 'Service C')
    task = service.tasks.create!(name: 'Task C', member:)
    service.order_services.create!(
      completed_at: 1.day.from_now.change(hour: 11, min: 0, sec: 0),
      partner_assignee_name: 'Pham Van C',
      priority_status: :urgent
    ).order_tasks.find_by!(task:)

    setting = AppSetting.create!(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: 'deleted-spreadsheet-id',
      google_sheets_sync_interval_value: 5,
      google_sheets_sync_interval_unit: :minutes
    )
    client = FakeGoogleSheetsClient.new(sheets: {})
    client.missing_spreadsheet_ids << 'deleted-spreadsheet-id'

    GoogleSheets::WorkbookSyncService.new(setting:, client:).call

    assert_equal 'generated-spreadsheet-id', setting.reload.google_sheets_spreadsheet_id
    assert_operator client.created_spreadsheet_titles.size, :>=, 1
    assert_equal 1, client.updated_ranges.size
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

  class FakeGoogleSheetsClient
    attr_reader :batch_updates, :cleared_ranges, :updated_ranges, :updated_values, :created_spreadsheet_titles, :updated_spreadsheet_titles, :missing_spreadsheet_ids

    def initialize(sheets:)
      @sheets = sheets
      @batch_updates = []
      @cleared_ranges = []
      @updated_ranges = []
      @updated_values = []
      @created_spreadsheet_titles = []
      @updated_spreadsheet_titles = []
      @missing_spreadsheet_ids = []
    end

    def create_spreadsheet(title:)
      @created_spreadsheet_titles << title
      { 'spreadsheetId' => 'generated-spreadsheet-id' }
    end

    def update_spreadsheet_title(_spreadsheet_id, title:)
      @updated_spreadsheet_titles << title
    end

    def spreadsheet_metadata(_spreadsheet_id)
      raise GoogleSheets::Client::NotFoundError, 'Requested entity was not found.' if @missing_spreadsheet_ids.include?(_spreadsheet_id)

      {
        'sheets' => @sheets.map do |title, sheet_id|
          properties = sheet_id.is_a?(Hash) ? sheet_id.merge('title' => title) : { 'title' => title, 'sheetId' => sheet_id }
          { 'properties' => properties }
        end
      }
    end

    def batch_update(_spreadsheet_id, requests)
      @batch_updates << requests
    end

    def clear_values(_spreadsheet_id, range)
      @cleared_ranges << range
    end

    def update_values(_spreadsheet_id, range, values)
      @updated_ranges << range
      @updated_values << values
    end
  end
end
