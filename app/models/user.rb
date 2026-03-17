# frozen_string_literal: true

class User < ApplicationParanoia
  has_secure_password

  enum :role, { admin: 0, member: 1 }, default: :member

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email,
            presence: { message: 'không được để trống' },
            uniqueness: { case_sensitive: false, message: 'đã tồn tại' },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: 'không đúng định dạng' }
end
