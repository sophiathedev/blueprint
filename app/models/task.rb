# frozen_string_literal: true

class Task < ApplicationParanoia
  belongs_to :service
  belongs_to :member, class_name: 'User', optional: true

  normalizes :name, with: ->(name) { name.to_s.squish }

  validates :name, presence: { message: 'không được để trống' }
  validates :member, presence: { message: 'không được để trống' }

  validate :member_must_be_member_role

  private

  def member_must_be_member_role
    return if member.blank? || member.member?

    errors.add(:member, 'phải là member hợp lệ')
  end
end
