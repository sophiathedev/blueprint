# frozen_string_literal: true

module Admin
  class SettingsController < BaseController
    def show
      @setting = AppSetting.current
    end

    def update
      @setting = AppSetting.current
      previous_telegram_api_key = @setting.telegram_api_key

      if @setting.update(setting_params)
        webhook_warning = sync_telegram_webhook_warning(previous_telegram_api_key:)
        flash[:warning] = webhook_warning if webhook_warning.present?
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

    def sync_telegram_webhook_warning(previous_telegram_api_key:)
      current_telegram_api_key = @setting.telegram_api_key
      return if previous_telegram_api_key == current_telegram_api_key

      if current_telegram_api_key.present?
        return local_webhook_warning if local_telegram_webhook_host?

        Telegram::Client.new(token: current_telegram_api_key).register_webhook!(base_url: request.base_url)
      elsif previous_telegram_api_key.present?
        Telegram::Client.new(token: previous_telegram_api_key).remove_webhook!
      end

      nil
    rescue Telegram::Client::Error => error
      "Telegram API key đã được lưu nhưng chưa đồng bộ webhook: #{error.message}"
    end

    def local_telegram_webhook_host?
      request.host.in?(%w[localhost 127.0.0.1 ::1])
    end

    def local_webhook_warning
      'Telegram API key đã được lưu. Domain hiện tại đang là localhost nên webhook chưa được tự động đăng ký với Telegram.'
    end
  end
end
