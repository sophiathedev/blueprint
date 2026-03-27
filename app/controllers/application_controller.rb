# frozen_string_literal: true

class ApplicationController < ActionController::Base
  SESSION_TIMEOUT = 10.hours
  RETURN_TO_SESSION_KEY = :return_to_after_authentication
  TELEGRAM_CONNECTION_PROMPT_SEEN_SESSION_KEY = :telegram_connection_prompt_seen

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
  before_action :expire_session_if_needed
  before_action :enforce_password_change_if_needed
  before_action :enforce_telegram_connection_if_needed

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

    store_return_to_location!
    redirect_to login_path, alert: 'Vui lòng đăng nhập để tiếp tục.'
  end

  def mark_session_authenticated!
    session[:authenticated_at] = Time.current.to_i
    session.delete(TELEGRAM_CONNECTION_PROMPT_SEEN_SESSION_KEY)
  end

  def enforce_password_change_if_needed
    return unless user_signed_in? && current_user.first_login?
    return if controller_name == 'users' && action_name.in?(%w[change_password perform_password_change])

    redirect_to change_password_path, alert: 'Vui lòng đổi mật khẩu trước khi tiếp tục.'
  end

  def expire_session_if_needed
    authenticated_at = session[:authenticated_at]
    return if authenticated_at.blank?

    return if Time.zone.at(authenticated_at.to_i) > SESSION_TIMEOUT.ago

    return_to_location = session[RETURN_TO_SESSION_KEY]
    reset_session
    session[RETURN_TO_SESSION_KEY] = return_to_location if return_to_location.present?
    redirect_to login_path, alert: 'Phiên đăng nhập đã hết hạn sau 10 tiếng. Vui lòng đăng nhập lại.'
  end

  def store_return_to_location!
    return unless request.get?
    return if request.xhr?
    return unless request.format.html?

    session[RETURN_TO_SESSION_KEY] = request.fullpath
  end

  def consume_return_to_location
    return_to_location = session.delete(RETURN_TO_SESSION_KEY).to_s
    return if return_to_location.blank?
    return unless return_to_location.start_with?('/')

    return_to_location
  end

  def post_authentication_path
    return telegram_connection_path if should_prompt_for_telegram_connection?

    consume_return_to_location || root_path
  end

  def enforce_telegram_connection_if_needed
    return unless user_signed_in?
    return if current_user.telegram_connected?
    return if controller_name == 'users' && action_name.in?(%w[change_password perform_password_change logout])
    return if controller_path.in?(%w[telegram_connections telegram_subscriptions])
    return if current_user.admin? && telegram_connection_prompt_seen?

    session[RETURN_TO_SESSION_KEY] = request.fullpath if storable_location_for_post_auth_redirect?
    redirect_to telegram_connection_path
  end

  def should_prompt_for_telegram_connection?
    return false unless user_signed_in?
    return false if current_user.telegram_connected?
    return false if current_user.admin? && telegram_connection_prompt_seen?

    true
  end

  def telegram_connection_prompt_seen?
    session[TELEGRAM_CONNECTION_PROMPT_SEEN_SESSION_KEY].present?
  end

  def mark_telegram_connection_prompt_seen!
    session[TELEGRAM_CONNECTION_PROMPT_SEEN_SESSION_KEY] = true
  end

  def storable_location_for_post_auth_redirect?
    request.get? && !request.xhr? && request.format.html?
  end
end
