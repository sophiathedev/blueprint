# frozen_string_literal: true

class Service < ApplicationParanoia
  belongs_to :partner
  has_many :tasks, dependent: :destroy

  normalizes :name, with: ->(name) { name.to_s.squish }

  validates :name, presence: { message: 'không được để trống' }, uniqueness: {
    case_sensitive: false,
    conditions: -> { where(deleted_at: nil) },
    message: 'đã tồn tại'
  }
end
