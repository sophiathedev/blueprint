# frozen_string_literal: true

require 'json'

class OrderService < ApplicationParanoia
  DATE_ONLY_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  enum :priority_status, { low: 0, medium: 1, high: 2, urgent: 3 }

  belongs_to :service
  has_many :order_tasks, dependent: :destroy

  normalizes :partner_assignee_name, with: ->(name) { name.to_s.squish }
  normalizes :google_sheet_link, with: ->(value) { value.to_s.strip }
  normalizes :customer_domain, with: ->(value) { value.to_s.strip }

  validates :completed_at, presence: { message: 'không được để trống' }
  validates :partner_assignee_name, presence: { message: 'không được để trống' }
  validates :google_sheet_link, presence: { message: 'không được để trống' }
  validates :customer_domain, presence: { message: 'không được để trống' }
  validates :priority_status, presence: { message: 'không được để trống' }

  before_validation :normalize_completed_at
  after_create_commit :create_order_tasks_from_service_tasks
  after_create_commit :enqueue_admin_telegram_notification
  after_commit :sync_deadline_check_job, on: %i[create update]
  after_commit :remove_deadline_check_job, on: :destroy
  validate :completed_at_cannot_be_in_the_past

  private

  def normalize_completed_at
    raw_value = completed_at_before_type_cast
    return if raw_value.blank?

    normalized_value =
      case raw_value
      when String
        Time.zone.parse("#{raw_value} 00:00") if raw_value.match?(DATE_ONLY_FORMAT)
      when Date
        raw_value.in_time_zone.beginning_of_day unless raw_value.is_a?(Time)
      end

    self.completed_at = normalized_value if normalized_value.present?
  end

  def completed_at_cannot_be_in_the_past
    return if completed_at.blank?
    return if completed_at >= Time.current.change(sec: 0)

    errors.add(:completed_at, 'phải từ thời điểm hiện tại trở đi')
  end

  def create_order_tasks_from_service_tasks
    service.tasks.find_each do |task|
      order_tasks.find_or_create_by!(task:)
    end
  end

  public

  def scheduled_deadline_job_ids
    raw_value = deadline_check_job_id.to_s.strip
    return [] if raw_value.blank?

    parsed_value = JSON.parse(raw_value)
    return parsed_value.filter_map(&:presence).uniq if parsed_value.is_a?(Array)

    [raw_value]
  rescue JSON::ParserError
    [raw_value]
  end

  def replace_scheduled_deadline_job_ids!(job_ids)
    normalized_job_ids = job_ids.filter_map(&:presence).uniq
    serialized_job_ids = normalized_job_ids.presence&.to_json

    update_column(:deadline_check_job_id, serialized_job_ids) unless destroyed?
    self.deadline_check_job_id = serialized_job_ids
  end

  def remove_scheduled_deadline_job_id!(job_id)
    replace_scheduled_deadline_job_ids!(scheduled_deadline_job_ids - [job_id])
  end

  def add_scheduled_deadline_job_id!(job_id)
    replace_scheduled_deadline_job_ids!(scheduled_deadline_job_ids + [job_id])
  end

  private

  def enqueue_admin_telegram_notification
    NotifyAdminsNewOrderJob.perform_async(id)
  end

  def sync_deadline_check_job
    return if completed_at.blank?
    return unless previous_changes.key?('id') || previous_changes.key?('completed_at')

    cancel_deadline_check_job

    job_ids = []
    reminder_time = completed_at - 1.day

    if reminder_time > Time.current
      job_ids << OrderDeadlineReminderJob.perform_at(reminder_time, id)
    end

    job_ids << OrderDeadlineMissJob.perform_at(completed_at, id)
    replace_scheduled_deadline_job_ids!(job_ids)
  end

  def remove_deadline_check_job
    cancel_deadline_check_job
  end

  def cancel_deadline_check_job
    job_ids = scheduled_deadline_job_ids
    return if job_ids.empty?

    if defined?(Sidekiq::Testing) && Sidekiq::Testing.fake?
      [OrderDeadlineReminderJob, OrderDeadlineMissJob, OrderDeadlineOverdueReminderJob].each do |job_class|
        job_class.jobs.reject! { |job| job_ids.include?(job['jid']) }
      end

      replace_scheduled_deadline_job_ids!([]) unless destroyed?
      return
    end

    require 'sidekiq/api'

    Sidekiq::ScheduledSet.new.each do |job|
      next unless job_ids.include?(job.jid)

      job.delete
    end

    replace_scheduled_deadline_job_ids!([]) unless destroyed?
  end
end
