# frozen_string_literal: true

require 'test_helper'

class AppSettingTest < ActiveSupport::TestCase
  test 'google sheets toggle can be enabled before interval is configured' do
    setting = AppSetting.new(
      google_sheets_enabled: true,
      google_sheets_sync_interval_value: nil,
      google_sheets_sync_interval_unit: nil
    )

    assert setting.valid?
  end

  test 'google sheets interval unit is required once interval value is entered' do
    setting = AppSetting.new(
      google_sheets_enabled: true,
      google_sheets_sync_interval_value: 5,
      google_sheets_sync_interval_unit: nil
    )

    assert_equal false, setting.valid?
    assert_includes setting.errors[:google_sheets_sync_interval_unit], 'không được để trống'
  end

  test 'google sheets interval label uses localized unit' do
    setting = AppSetting.new(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: 'sheet-id',
      google_sheets_sync_interval_value: 5,
      google_sheets_sync_interval_unit: :minutes
    )

    assert_equal '5 phút', setting.google_sheets_interval_label
  end
end
