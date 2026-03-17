# frozen_string_literal: true

class Partner < ApplicationParanoia
  normalizes :name, with: ->(name) { name.to_s.squish }

  validates :name, presence: { message: 'không được để trống' }
end
