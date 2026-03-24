# frozen_string_literal: true

require 'test_helper'

class AdminSettingsFlowTest < ActionDispatch::IntegrationTest
  test 'admin can save telegram api key and sync webhook on a public host' do
    admin = build_admin
    fake_client = FakeTelegramClient.new

    host! 'app.example.com'
    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    with_stubbed_constructor(Telegram::Client, fake_client) do
      patch admin_settings_path, params: {
        app_setting: {
          telegram_api_key: '123456:telegram-token'
        }
      }
    end

    assert_redirected_to admin_settings_path
    assert_equal '123456:telegram-token', AppSetting.current.reload.telegram_api_key
    assert_equal [ 'http://app.example.com' ], fake_client.registered_base_urls
  end

  test 'admin can save google sheets settings and schedule sync' do
    admin = build_admin

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    patch admin_settings_path, params: {
      app_setting: {
        google_sheets_enabled: '1',
        google_sheets_spreadsheet_id: 'spreadsheet-id',
        google_sheets_tab_prefix: 'Blueprint',
        google_sheets_sync_interval_value: '5',
        google_sheets_sync_interval_unit: 'minutes'
      }
    }

    assert_redirected_to admin_settings_path

    setting = AppSetting.current.reload
    assert_equal true, setting.google_sheets_enabled?
    assert_equal 'spreadsheet-id', setting.google_sheets_spreadsheet_id
    assert_equal 'minutes', setting.google_sheets_sync_interval_unit
    assert_equal 5, setting.google_sheets_sync_interval_value
    assert_equal 'scheduled', setting.google_sheets_last_sync_status
    assert_equal 1, GoogleSheetsSyncJob.jobs.size
  end

  test 'admin can save google sheets settings without spreadsheet id' do
    admin = build_admin

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    patch admin_settings_path, params: {
      app_setting: {
        google_sheets_enabled: '1',
        google_sheets_spreadsheet_id: '',
        google_sheets_tab_prefix: 'Blueprint',
        google_sheets_sync_interval_value: '5',
        google_sheets_sync_interval_unit: 'minutes'
      }
    }

    assert_redirected_to admin_settings_path

    setting = AppSetting.current.reload
    assert_equal true, setting.google_sheets_enabled?
    assert_nil setting.google_sheets_spreadsheet_id
    assert_equal 'scheduled', setting.google_sheets_last_sync_status
  end

  test 'admin can enqueue manual google sheets sync' do
    admin = build_admin
    AppSetting.create!(
      google_sheets_enabled: true,
      google_sheets_spreadsheet_id: 'spreadsheet-id',
      google_sheets_tab_prefix: 'Blueprint',
      google_sheets_sync_interval_value: 5,
      google_sheets_sync_interval_unit: :minutes
    )

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    assert_difference('GoogleSheetsSyncJob.jobs.size', 1) do
      post admin_settings_sync_google_sheets_path, params: { sync_mode: 'manual' }
    end

    assert_redirected_to admin_settings_path
    assert_equal 'scheduled', AppSetting.current.reload.google_sheets_last_sync_status
  end

  private

  def build_admin
    User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current
    )
  end

  class FakeTelegramClient
    attr_reader :registered_base_urls

    def initialize
      @registered_base_urls = []
    end

    def register_webhook!(base_url:)
      @registered_base_urls << base_url
    end
  end
end
