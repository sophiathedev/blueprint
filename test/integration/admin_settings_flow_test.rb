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
