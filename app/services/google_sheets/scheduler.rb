# frozen_string_literal: true

module GoogleSheets
  class Scheduler
    class << self
      def next_run_at(setting, from: Time.current)
        return if setting.blank? || !setting.google_sheets_auto_sync_configured?

        interval = interval_duration(setting)
        return if interval.blank?

        from.change(sec: 0) + interval
      end

      def schedule_next_sync!(setting, from: Time.current)
        clear_scheduled_sync!(setting)
        return unless setting.google_sheets_auto_sync_configured?

        run_at = next_run_at(setting, from:)
        return if run_at.blank?

        job_id = GoogleSheetsSyncJob.perform_at(run_at, 'scheduled')
        setting.update_google_sheets_schedule!(job_id:, next_sync_at: run_at)
      end

      def clear_scheduled_sync!(setting)
        job_id = setting&.google_sheets_next_sync_job_id.to_s
        return if job_id.blank?

        if defined?(Sidekiq::Testing) && Sidekiq::Testing.fake?
          GoogleSheetsSyncJob.jobs.reject! { |job| job['jid'] == job_id }
        else
          require 'sidekiq/api'

          Sidekiq::ScheduledSet.new.each do |job|
            next unless job.jid == job_id

            job.delete
          end
        end

        setting.update_google_sheets_schedule!(job_id: nil, next_sync_at: nil)
      end

      private

      def interval_duration(setting)
        value = setting.google_sheets_sync_interval_value.to_i
        return if value <= 0

        case setting.google_sheets_sync_interval_unit
        when 'minutes'
          value.minutes
        when 'hours'
          value.hours
        when 'days'
          value.days
        end
      end
    end
  end
end
