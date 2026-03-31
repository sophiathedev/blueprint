# frozen_string_literal: true

require 'test_helper'

class TelegramSubscriptionsFlowTest < ActionDispatch::IntegrationTest
  test 'member without telegram is redirected to the standalone telegram connection page after login' do
    member = build_member('Telegram Member')
 
    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    assert_redirected_to telegram_connection_path

    get telegram_connection_path

    assert_response :success
    assert_match 'Liên kết Telegram', response.body
    assert_match 'Liên kết với Telegram', response.body
    assert_no_match 'Bỏ qua', response.body
    assert_no_match 'data-controller="sidebar-layout"', response.body
    assert_no_match 'SidebarComponent', response.body

    get root_path

    assert_redirected_to telegram_connection_path
  end

  test 'admin without telegram only sees the telegram connection page once per login session' do
    admin = build_admin('Telegram Admin')

    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    assert_redirected_to telegram_connection_path

    get telegram_connection_path

    assert_response :success
    assert_match 'Bỏ qua', response.body

    get root_path

    assert_response :success
    assert_no_match 'Liên kết Telegram', response.body

    delete logout_path
    post login_path, params: { user: { email: admin.email, password: 'Password1!' } }

    assert_redirected_to telegram_connection_path
  end

  test 'member can generate a telegram deep link from the standalone telegram connection page' do
    member = build_member('Telegram Member')
    fake_client = FakeTelegramClient.new
    AppSetting.current.update!(telegram_api_key: 'configured-telegram-token')

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    get telegram_connection_path

    assert_response :success
    assert_match 'Liên kết với Telegram', response.body

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

  test 'member sees a flash when confirming telegram connection before actually linking' do
    member = build_member('Unlinked Member')

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    get telegram_connection_path(check_status: true)

    assert_response :success
    assert_match 'Bạn chưa liên kết Telegram.', response.body
  end

  test 'telegram connection status returns whether the current user is already linked' do
    member = build_member('Status Member', telegram_chat_id: 123_321, telegram_connected_at: Time.current)

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }
    get status_telegram_connection_path, as: :json

    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal true, payload['connected']
    assert_equal root_path, payload['redirect_url']
  end

  test 'member with telegram already linked goes straight into the app after login' do
    member = build_member('Connected Member', telegram_chat_id: 987_654, telegram_connected_at: Time.current)

    post login_path, params: { user: { email: member.email, password: 'Password1!' } }

    assert_redirected_to root_path
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

  def build_member(name, telegram_chat_id: nil, telegram_connected_at: nil)
    User.create!(
      email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :member,
      name:,
      last_login_at: Time.current,
      telegram_chat_id:,
      telegram_connected_at:
    )
  end

  def build_admin(name, telegram_chat_id: nil, telegram_connected_at: nil)
    User.create!(
      email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      password_confirmation: 'Password1!',
      role: :admin,
      last_login_at: Time.current,
      telegram_chat_id:,
      telegram_connected_at:
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
