# frozen_string_literal: true

module Admin
  class SettingsController < BaseController
    def show
      @setting = AppSetting.current
    end

    def update
      @setting = AppSetting.current

      if @setting.update(setting_params)
        redirect_to admin_settings_path, notice: 'Cập nhật settings thành công.'
      else
        flash.now[:alert] = @setting.errors.full_messages
        render :show, status: :unprocessable_entity
      end
    end

    private

    def setting_params
      params.expect(app_setting: [ :telegram_api_key ])
    end
  end
end
