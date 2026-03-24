# frozen_string_literal: true

require 'test_helper'

class GoogleSheetsSyncJobTest < ActiveSupport::TestCase
  test 'marks success and schedules next run when sync succeeds' do
    setting = AppSetting.create!(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: 'spreadsheet-id',
      google_sheets_tab_prefix: 'Blueprint',
      google_sheets_sync_interval_value: 5,
      google_sheets_sync_interval_unit: :minutes
    )
    fake_sync_service = FakeWorkbookSyncService.new

    with_stubbed_constructor(GoogleSheets::WorkbookSyncService, fake_sync_service) do
      freeze_time do
        GoogleSheetsSyncJob.new.perform('manual')
      end
    end

    setting.reload
    assert_equal 'success', setting.google_sheets_last_sync_status
    assert_nil setting.google_sheets_last_sync_error
    assert_equal 1, fake_sync_service.calls
    assert_equal 1, GoogleSheetsSyncJob.jobs.size
    assert_not_nil setting.google_sheets_next_sync_at
  end

  test 'stores failure and still schedules next run when sync fails' do
    setting = AppSetting.create!(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: 'spreadsheet-id',
      google_sheets_tab_prefix: 'Blueprint',
      google_sheets_sync_interval_value: 1,
      google_sheets_sync_interval_unit: :hours
    )
    fake_sync_service = FailingWorkbookSyncService.new

    with_stubbed_constructor(GoogleSheets::WorkbookSyncService, fake_sync_service) do
      freeze_time do
        GoogleSheetsSyncJob.new.perform('scheduled')
      end
    end

    setting.reload
    assert_equal 'failed', setting.google_sheets_last_sync_status
    assert_match 'boom', setting.google_sheets_last_sync_error
    assert_equal 1, GoogleSheetsSyncJob.jobs.size
    assert_not_nil setting.google_sheets_next_sync_at
  end

  class FakeWorkbookSyncService
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def call
      @calls += 1
    end
  end

  class FailingWorkbookSyncService
    def call
      raise GoogleSheets::Client::Error, 'boom'
    end
  end
end
