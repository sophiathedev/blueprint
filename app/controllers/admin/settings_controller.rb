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
        sync_google_sheets_schedule
        webhook_warning = sync_telegram_webhook_warning(previous_telegram_api_key:)
        flash[:warning] = webhook_warning if webhook_warning.present?
        redirect_to admin_settings_path, notice: 'Cập nhật settings thành công.'
      else
        flash.now[:alert] = @setting.errors.full_messages
        render :show, status: :unprocessable_entity
      end
    end

    def sync_google_sheets
      @setting = AppSetting.current

      unless @setting.google_sheets_manual_sync_ready?
        return redirect_to admin_settings_path, alert: 'Vui lòng cấu hình Google Sheets đầy đủ trước khi sync.'
      end

      GoogleSheets::Scheduler.clear_scheduled_sync!(@setting)
      job_id = GoogleSheetsSyncJob.perform_async(sync_reason_param)
      @setting.update!(
        google_sheets_cancel_requested: false,
        google_sheets_current_job_id: job_id,
        google_sheets_last_sync_status: 'scheduled',
        google_sheets_last_sync_error: nil,
        google_sheets_next_sync_job_id: nil,
        google_sheets_next_sync_at: nil,
        google_sheets_sync_progress: 0
      )

      redirect_to admin_settings_path, notice: manual_sync_notice
    end

    def cancel_google_sheets_sync
      @setting = AppSetting.current

      GoogleSheets::Scheduler.clear_scheduled_sync!(@setting)
      cancel_google_sheets_jobs!(@setting.google_sheets_current_job_id)
      @setting.request_google_sheets_cancel!
      @setting.update!(
        google_sheets_current_job_id: nil,
        google_sheets_next_sync_job_id: nil,
        google_sheets_next_sync_at: nil,
        google_sheets_sync_progress: 0
      )

      redirect_to admin_settings_path, notice: 'Đã gửi yêu cầu hủy sync Google Sheets.'
    end

    def google_sheets_sync_status
      @setting = AppSetting.current

       response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
       response.headers['Pragma'] = 'no-cache'
       response.headers['Expires'] = '0'

      render json: {
        status: @setting.google_sheets_last_sync_status,
        status_label: @setting.google_sheets_last_sync_status_label,
        progress: @setting.google_sheets_sync_progress.to_i,
        last_synced_at: @setting.google_sheets_display_time(@setting.google_sheets_last_synced_at),
        next_sync_at: @setting.google_sheets_display_time(@setting.google_sheets_next_sync_at),
        error: @setting.google_sheets_last_sync_error,
        cancellable: @setting.google_sheets_cancellable?
      }
    end

    private

    def setting_params
      params.expect(app_setting: [
        :telegram_api_key,
        :google_sheets_enabled,
        :google_sheets_sync_interval_value,
        :google_sheets_sync_interval_unit
      ])
    end

    def sync_google_sheets_schedule
      if @setting.google_sheets_auto_sync_configured?
        GoogleSheets::Scheduler.schedule_next_sync!(@setting)
        @setting.update!(
          google_sheets_cancel_requested: false,
          google_sheets_last_sync_status: 'scheduled',
          google_sheets_last_sync_error: nil,
          google_sheets_sync_progress: 0
        )
      else
        GoogleSheets::Scheduler.clear_scheduled_sync!(@setting)
      end
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

    def sync_reason_param
      params[:sync_mode] == 'full' ? 'manual_full' : 'manual'
    end

    def manual_sync_notice
      'Đã đưa yêu cầu sync Google Sheets vào hàng đợi.'
    end

    def cancel_google_sheets_jobs!(job_id)
      normalized_job_id = job_id.to_s
      return if normalized_job_id.blank?

      if defined?(Sidekiq::Testing) && Sidekiq::Testing.fake?
        GoogleSheetsSyncJob.jobs.reject! { |job| job['jid'] == normalized_job_id }
        return
      end

      require 'sidekiq/api'

      Sidekiq::Queue.new.each do |job|
        next unless job.jid == normalized_job_id

        job.delete
      end

      Sidekiq::ScheduledSet.new.each do |job|
        next unless job.jid == normalized_job_id

        job.delete
      end

      Sidekiq::RetrySet.new.each do |job|
        next unless job.jid == normalized_job_id

        job.delete
      end
    end
  end
end
