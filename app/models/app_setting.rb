# frozen_string_literal: true

class AppSetting < ApplicationRecord
  normalizes :telegram_api_key, with: ->(value) { value.to_s.strip.presence }
  normalizes :google_sheets_spreadsheet_id, with: ->(value) { value.to_s.strip.presence }
  normalizes :google_sheets_tab_prefix, with: ->(value) { value.to_s.strip.presence }

  enum :google_sheets_sync_interval_unit, { minutes: 0, hours: 1, days: 2 }, prefix: true

  GOOGLE_SHEETS_SYNC_STATUSES = %w[idle scheduled syncing success failed cancelled].freeze

  validates :telegram_api_key, length: { maximum: 255, message: 'không được vượt quá 255 ký tự' }, allow_nil: true
  validates :google_sheets_sync_interval_value,
            numericality: { only_integer: true, greater_than: 0, message: 'phải là số nguyên dương' },
            if: :google_sheets_sync_interval_value_present?
  validates :google_sheets_sync_interval_unit,
            presence: { message: 'không được để trống' },
            if: :google_sheets_sync_interval_value_present?
  validates :google_sheets_last_sync_status,
            inclusion: { in: GOOGLE_SHEETS_SYNC_STATUSES, message: 'không hợp lệ' },
            allow_nil: true
  validates :google_sheets_sync_progress,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100,
              message: 'không hợp lệ'
            }

  before_validation :apply_google_sheets_defaults

  def self.current
    order(:id).first_or_initialize
  end

  def telegram_configured?
    telegram_api_key.present?
  end

  def google_sheets_auto_sync_configured?
    google_sheets_enabled? &&
      google_sheets_sync_interval_value.to_i.positive? &&
      google_sheets_sync_interval_unit.present?
  end

  def google_sheets_manual_sync_ready?
    true
  end

  def google_sheets_interval_label
    return 'Chưa cấu hình' if google_sheets_sync_interval_value.blank? || google_sheets_sync_interval_unit.blank?

    "#{google_sheets_sync_interval_value} #{google_sheets_sync_unit_label}"
  end

  def google_sheets_display_time(time)
    return if time.blank?

    time.in_time_zone('Asia/Ho_Chi_Minh').strftime('%d/%m/%Y %H:%M')
  end

  def google_sheets_spreadsheet_link
    return if google_sheets_spreadsheet_id.blank?

    "https://docs.google.com/spreadsheets/d/#{google_sheets_spreadsheet_id}/edit"
  end

  def google_sheets_sync_unit_label
    case google_sheets_sync_interval_unit
    when 'minutes'
      'phút'
    when 'hours'
      'giờ'
    when 'days'
      'ngày'
    else
      google_sheets_sync_interval_unit.to_s
    end
  end

  def google_sheets_last_sync_status_label
    case google_sheets_last_sync_status
    when 'idle'
      'Chưa sync'
    when 'scheduled'
      'Đã lên lịch'
    when 'syncing'
      'Đang sync'
    when 'success'
      'Sync thành công'
    when 'failed'
      'Sync thất bại'
    when 'cancelled'
      'Đã hủy sync'
    else
      'Chưa sync'
    end
  end

  def google_sheets_in_progress?
    google_sheets_last_sync_status.in?(%w[scheduled syncing])
  end

  def google_sheets_cancellable?
    google_sheets_in_progress? || google_sheets_current_job_id.present? || google_sheets_next_sync_job_id.present?
  end

  def google_sheets_sync_progress_ratio
    google_sheets_sync_progress.to_i.clamp(0, 100) / 100.0
  end

  def update_google_sheets_progress!(progress)
    normalized_progress = progress.to_i.clamp(0, 100)

    update_columns(
      google_sheets_sync_progress: normalized_progress,
      updated_at: Time.current
    )

    self.google_sheets_sync_progress = normalized_progress
  end

  def request_google_sheets_cancel!
    update!(
      google_sheets_cancel_requested: true,
      google_sheets_last_sync_status: 'cancelled',
      google_sheets_last_sync_error: nil
    )
  end

  def update_google_sheets_schedule!(job_id:, next_sync_at:)
    update_columns(
      google_sheets_next_sync_job_id: job_id,
      google_sheets_next_sync_at: next_sync_at,
      updated_at: Time.current
    )

    self.google_sheets_next_sync_job_id = job_id
    self.google_sheets_next_sync_at = next_sync_at
  end

  private

  def apply_google_sheets_defaults
    self.google_sheets_tab_prefix = 'Blueprint' if google_sheets_tab_prefix.blank?
    self.google_sheets_last_sync_status = 'idle' if google_sheets_last_sync_status.blank?
  end

  def google_sheets_sync_interval_value_present?
    google_sheets_sync_interval_value.present?
  end
end
