# frozen_string_literal: true

class UsersController < ApplicationController
  layout 'auth'
  before_action :require_authentication, only: %i[change_password perform_password_change]
  before_action :redirect_authenticated_user, only: :login
  before_action :redirect_if_password_already_changed, only: %i[change_password perform_password_change]

  def login; end

  def perform_sign_in
    @email = login_params[:email].to_s.strip.downcase
    user = User.find_by(email: @email)

    if user&.authenticate(login_params[:password].to_s)
      session[:user_id] = user.id

      if user.first_login?
        redirect_to change_password_path, notice: 'Vui lòng đổi mật khẩu ở lần đăng nhập đầu tiên.'
      else
        user.update_column(:last_login_at, Time.current)
        redirect_to root_path, notice: 'Đăng nhập thành công.'
      end
    else
      flash.now[:alert] = 'Email hoặc mật khẩu không đúng.'
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    reset_session
    redirect_to root_path, notice: 'Đăng xuất thành công.'
  end

  def change_password; end

  def perform_password_change
    @password = password_change_params[:password]
    @password_confirmation = password_change_params[:password_confirmation]

    if current_user.update(
      password: @password,
      password_confirmation: @password_confirmation,
      last_login_at: Time.current
    )
      redirect_to root_path, notice: 'Đổi mật khẩu thành công.'
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :change_password, status: :unprocessable_entity
    end
  end

  private

  def login_params
    params.expect(user: %i[email password])
  end

  def password_change_params
    params.expect(user: %i[password password_confirmation])
  end

  def redirect_authenticated_user
    return unless user_signed_in?

    if current_user.first_login?
      redirect_to change_password_path
    else
      redirect_to root_path
    end
  end

  def redirect_if_password_already_changed
    redirect_to root_path unless current_user.first_login?
  end
end
