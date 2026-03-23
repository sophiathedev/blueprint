# frozen_string_literal: true

class TelegramSubscriptionsController < ApplicationController
  before_action :require_authentication
  skip_forgery_protection only: :create

  def create
    connection_token = current_user.issue_telegram_connection_token!
    telegram_deep_link = Telegram::Client.new.deep_link_for(connection_token)

    redirect_to telegram_deep_link, allow_other_host: true
  rescue Telegram::Client::MissingConfigurationError
    redirect_to root_path, alert: 'Telegram bot chưa được cấu hình. Vui lòng liên hệ admin để bật tính năng này.'
  rescue Telegram::Client::Error => error
    redirect_to root_path, alert: "Không thể mở Telegram bot: #{error.message}"
  end
end
