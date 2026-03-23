# frozen_string_literal: true

class OrderService < ApplicationParanoia
  DATE_ONLY_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  enum :priority_status, { low: 0, medium: 1, high: 2, urgent: 3 }

  belongs_to :service
  has_many :order_tasks, dependent: :destroy

  normalizes :partner_assignee_name, with: ->(name) { name.to_s.squish }

  validates :completed_at, presence: { message: 'không được để trống' }
  validates :partner_assignee_name, presence: { message: 'không được để trống' }
  validates :priority_status, presence: { message: 'không được để trống' }

  before_validation :normalize_completed_at
  after_create_commit :create_order_tasks_from_service_tasks
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

  def sync_deadline_check_job
    return unless previous_changes.key?('id') || previous_changes.key?('completed_at')

    cancel_deadline_check_job

    jid = OrderDeadlineMissJob.perform_at(completed_at, id)
    update_column(:deadline_check_job_id, jid)
    self.deadline_check_job_id = jid
  end

  def remove_deadline_check_job
    cancel_deadline_check_job
  end

  def cancel_deadline_check_job
    return if deadline_check_job_id.blank?

    if defined?(Sidekiq::Testing) && Sidekiq::Testing.fake?
      OrderDeadlineMissJob.jobs.reject! { |job| job['jid'] == deadline_check_job_id }
      return
    end

    require 'sidekiq/api'

    Sidekiq::ScheduledSet.new.each do |job|
      next unless job.jid == deadline_check_job_id

      job.delete
      break
    end
  end
end
