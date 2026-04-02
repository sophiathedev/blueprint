# frozen_string_literal: true

class TelegramConnectionsController < ApplicationController
  layout false

  before_action :require_authentication
  before_action :redirect_if_already_connected, only: :show
  before_action :require_existing_connection!, only: :change
  before_action :mark_admin_prompt_seen, only: :show

  def show
    @change_mode = false
    @confirm_visible = current_user.telegram_connection_pending?
    flash.now[:alert] = 'Bạn chưa liên kết Telegram.' if params[:check_status].present?
  end

  def change
    @change_mode = true
    @confirm_visible = current_user.telegram_connection_pending?

    if params[:check_status].present?
      return flash.now[:alert] = 'Bạn chưa hoàn tất đổi tài khoản Telegram.' if current_user.telegram_connection_pending?

      redirect_to root_path, notice: 'Đã cập nhật tài khoản Telegram.'
      return
    end

    render :show
  end

  def status
    render json: {
      connected: current_user.telegram_connected? && !current_user.telegram_connection_pending?,
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

  def require_existing_connection!
    return if current_user.telegram_connected?

    redirect_to telegram_connection_path, alert: 'Bạn chưa liên kết Telegram nên chưa thể đổi tài khoản.'
  end
end
