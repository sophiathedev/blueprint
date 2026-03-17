# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
  before_action :enforce_password_change_if_needed

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def user_signed_in?
    current_user.present?
  end

  def require_authentication
    return if user_signed_in?

    redirect_to login_path, alert: 'Vui lòng đăng nhập để tiếp tục.'
  end

  def enforce_password_change_if_needed
    return unless user_signed_in? && current_user.first_login?
    return if controller_name == 'users' && action_name.in?(%w[change_password perform_password_change])

    redirect_to change_password_path, alert: 'Vui lòng đổi mật khẩu trước khi tiếp tục.'
  end
end
