# frozen_string_literal: true

class TelegramConnectionsController < ApplicationController
  layout false

  before_action :require_authentication
  before_action :redirect_if_already_connected
  before_action :mark_admin_prompt_seen, only: :show
  skip_before_action :redirect_if_already_connected, only: :status

  def show
    flash.now[:alert] = 'Bạn chưa liên kết Telegram.' if params[:check_status].present?
  end

  def status
    render json: {
      connected: current_user.telegram_connected?,
      redirect_url: root_path
    }
  end

  private

  def mark_admin_prompt_seen
    return unless current_user.admin?

    mark_telegram_connection_prompt_seen!
  end

  def redirect_if_already_connected
    return unless current_user.telegram_connected?

    redirect_to consume_return_to_location || root_path
  end
end
