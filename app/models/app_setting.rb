# frozen_string_literal: true

class AppSetting < ApplicationRecord
  normalizes :telegram_api_key, with: ->(value) { value.to_s.strip.presence }

  validates :telegram_api_key, length: { maximum: 255, message: 'không được vượt quá 255 ký tự' }, allow_nil: true

  def self.current
    order(:id).first_or_initialize
  end
end
