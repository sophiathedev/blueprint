# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout 'admin'

    before_action :require_authentication
    before_action :require_admin

    private

    def require_admin
      return if current_user&.admin?

      redirect_to root_path, alert: 'Bạn không có quyền truy cập khu vực quản trị.'
    end
  end
end
