# frozen_string_literal: true

require 'test_helper'

class TelegramSubscriptionsFlowTest < ActionDispatch::IntegrationTest
  test 'member can generate a telegram deep link from the user dropdown' do
    member = build_member('Telegram Member')
    fake_client = FakeTelegramClient.new
    AppSetting.current.update!(telegram_api_key: 'configured-telegram-token')

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    get root_path

    assert_response :success
    assert_match 'Đăng ký nhận thông báo Telegram', response.body

    with_stubbed_constructor(Telegram::Client, fake_client) do
      post telegram_subscription_path
    end

    assert_response :redirect
    assert_match %r{\Ahttps://t\.me/blueprint_bot\?start=}, response.location

    raw_token = Rack::Utils.parse_query(URI.parse(response.location).query).fetch('start')
    member.reload

    assert_equal member, User.find_by_telegram_connection_token(raw_token)
    assert_not_nil member.telegram_connection_token_generated_at
  end

  test 'telegram webhook links chat id to the matching user' do
    member = build_member('Webhook Member')
    raw_token = member.issue_telegram_connection_token!
    fake_client = FakeTelegramClient.new

    with_stubbed_constructor(Telegram::Client, fake_client) do
      post telegram_webhook_path,
           params: {
             message: {
               chat: { id: 987_654_321, type: 'private' },
               text: "/start #{raw_token}"
             }
           }.to_json,
           headers: {
             'CONTENT_TYPE' => 'application/json',
             Telegram::Client::SECRET_HEADER => 'telegram-secret'
           }
    end

    assert_response :success

    member.reload
    assert_equal 987_654_321, member.telegram_chat_id
    assert_not_nil member.telegram_connected_at
    assert_nil member.telegram_connection_token_digest
    assert_includes fake_client.sent_messages.last.fetch(:text), member.display_name
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

  class FakeTelegramClient
    attr_reader :sent_messages

    def initialize
      @sent_messages = []
    end

    def deep_link_for(connection_token)
      "https://t.me/blueprint_bot?start=#{connection_token}"
    end

    def webhook_secret_valid?(secret_token)
      secret_token == 'telegram-secret'
    end

    def send_message(chat_id:, text:, **)
      @sent_messages << { chat_id:, text: }
    end
  end
end
