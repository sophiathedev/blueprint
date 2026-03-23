# frozen_string_literal: true

class OrderTask < ApplicationParanoia
  belongs_to :order_service
  belongs_to :task

  validates :task_id, uniqueness: { scope: :order_service_id }

  before_validation :normalize_completion_state

  scope :visible_to, lambda { |user|
    return all if user.blank? || user.admin?

    joins(:task).where(tasks: { member_id: user.id })
  }

  scope :for_user_order_services, lambda { |user|
    visible_to(user).select(:order_service_id).distinct
  }

  private

  def normalize_completion_state
    if is_completed?
      self.mark_completed_at ||= Time.current.change(sec: 0)
    else
      self.mark_completed_at = nil
    end
  end
end
