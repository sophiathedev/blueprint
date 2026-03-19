# frozen_string_literal: true

class Partner < ApplicationParanoia
  has_many :services, dependent: :destroy

  normalizes :name, with: ->(name) { name.to_s.squish }

  validates :name, presence: { message: 'không được để trống' }
end
