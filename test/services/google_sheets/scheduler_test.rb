# frozen_string_literal: true

require 'test_helper'

class GoogleSheetsSchedulerTest < ActiveSupport::TestCase
  test 'computes next run for minutes' do
    setting = build_setting(value: 5, unit: :minutes)
    now = Time.zone.parse('2026-03-24 10:12:34')

    assert_equal Time.zone.parse('2026-03-24 10:17:00'), GoogleSheets::Scheduler.next_run_at(setting, from: now)
  end

  test 'computes next run for hours' do
    setting = build_setting(value: 2, unit: :hours)
    now = Time.zone.parse('2026-03-24 10:12:34')

    assert_equal Time.zone.parse('2026-03-24 12:12:00'), GoogleSheets::Scheduler.next_run_at(setting, from: now)
  end

  test 'computes next run for days' do
    setting = build_setting(value: 1, unit: :days)
    now = Time.zone.parse('2026-03-24 10:12:34')

    assert_equal Time.zone.parse('2026-03-25 10:12:00'), GoogleSheets::Scheduler.next_run_at(setting, from: now)
  end

  test 'schedule_next_sync stores next job metadata' do
    setting = build_setting(value: 5, unit: :minutes)

    freeze_time do
      GoogleSheets::Scheduler.schedule_next_sync!(setting)
    end

    assert_equal 1, GoogleSheetsSyncJob.jobs.size
    assert_not_nil setting.reload.google_sheets_next_sync_job_id
    assert_not_nil setting.google_sheets_next_sync_at
  end

  test 'clear_scheduled_sync removes queued scheduled job in fake mode' do
    setting = build_setting(value: 5, unit: :minutes)

    freeze_time do
      GoogleSheets::Scheduler.schedule_next_sync!(setting)
    end

    assert_equal 1, GoogleSheetsSyncJob.jobs.size

    GoogleSheets::Scheduler.clear_scheduled_sync!(setting.reload)

    assert_equal 0, GoogleSheetsSyncJob.jobs.size
    assert_nil setting.reload.google_sheets_next_sync_job_id
    assert_nil setting.google_sheets_next_sync_at
  end

  private

  def build_setting(value:, unit:)
    AppSetting.create!(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: 'spreadsheet-id',
      google_sheets_tab_prefix: 'Blueprint',
      google_sheets_sync_interval_value: value,
      google_sheets_sync_interval_unit: unit
    )
  end
end
