# frozen_string_literal: true

class User < ApplicationParanoia
  PASSWORD_SPECIAL_CHARACTERS = %w[! @ # $ % ^ & * - _].freeze

  has_secure_password

  enum :role, { admin: 0, member: 1 }, default: :member

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :name, presence: { message: 'không được để trống' }, if: :member?
  validates :email,
            presence: { message: 'không được để trống' },
            uniqueness: { case_sensitive: false, message: 'đã tồn tại' },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: 'không đúng định dạng' }

  validates :password, length: { minimum: 8, message: 'phải có ít nhất 8 ký tự' }, allow_nil: true

  def self.generate_strong_password(length: 14)
    raise ArgumentError, 'length must be at least 8' if length < 8

    required_characters = [
      sample_from(('a'..'z').to_a),
      sample_from(('A'..'Z').to_a),
      sample_from(('0'..'9').to_a),
      sample_from(PASSWORD_SPECIAL_CHARACTERS)
    ]

    character_pool = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + PASSWORD_SPECIAL_CHARACTERS
    remaining_characters = Array.new(length - required_characters.length) { sample_from(character_pool) }

    (required_characters + remaining_characters).sort_by { SecureRandom.random_number }.join
  end

  def first_login?
    last_login_at.nil?
  end

  def last_login_label
    return 'Chưa đăng nhập' if last_login_at.blank?

    last_login_at.in_time_zone.strftime('%d/%m/%Y %H:%M')
  end

  def role_label
    admin? ? 'Admin' : 'Member'
  end

  def display_name
    name.presence || email
  end

  def self.sample_from(characters)
    characters[SecureRandom.random_number(characters.length)]
  end
  private_class_method :sample_from
end
