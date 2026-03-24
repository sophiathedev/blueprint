# frozen_string_literal: true

class GoogleSheetsSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform(reason = 'scheduled')
    setting = AppSetting.current

    setting.update!(
      google_sheets_current_job_id: jid,
      google_sheets_last_sync_status: 'syncing',
      google_sheets_last_sync_error: nil,
      google_sheets_next_sync_job_id: nil,
      google_sheets_next_sync_at: nil,
      google_sheets_sync_progress: 0
    )

    GoogleSheets::WorkbookSyncService.new(setting:).call

    setting.update!(
      google_sheets_cancel_requested: false,
      google_sheets_current_job_id: nil,
      google_sheets_last_synced_at: Time.current,
      google_sheets_last_sync_status: 'success',
      google_sheets_last_sync_error: nil,
      google_sheets_sync_progress: 100
    )
  rescue GoogleSheets::WorkbookSyncService::CancelledError
    setting&.update!(
      google_sheets_current_job_id: nil,
      google_sheets_last_sync_status: 'cancelled',
      google_sheets_last_sync_error: nil,
      google_sheets_sync_progress: 0
    )
  rescue GoogleSheets::Client::Error => e
    setting&.update!(
      google_sheets_cancel_requested: false,
      google_sheets_current_job_id: nil,
      google_sheets_last_sync_status: 'failed',
      google_sheets_last_sync_error: e.message
    )
    Rails.logger.error("[GoogleSheetsSyncJob] #{reason}: #{e.message}")
  ensure
    if setting&.google_sheets_auto_sync_configured? && !setting.google_sheets_cancel_requested?
      GoogleSheets::Scheduler.schedule_next_sync!(setting)
    end
  end
end
