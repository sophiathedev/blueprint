# frozen_string_literal: true

require 'digest'

class User < ApplicationParanoia
  PASSWORD_SPECIAL_CHARACTERS = %w[! @ # $ % ^ & * - _].freeze
  TELEGRAM_CONNECTION_TOKEN_TTL = 30.minutes

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
  validates :telegram_chat_id, uniqueness: { message: 'đã được kết nối với tài khoản khác' }, allow_nil: true

  scope :telegram_connected, -> { where.not(telegram_chat_id: nil) }

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

  def telegram_connected?
    telegram_chat_id.present?
  end

  def telegram_connected_label
    return 'Chưa kết nối Telegram' unless telegram_connected?
    return 'Đã kết nối Telegram' if telegram_connected_at.blank?

    "Đã kết nối lúc #{telegram_connected_at.in_time_zone.strftime('%d/%m/%Y %H:%M')}"
  end

  def issue_telegram_connection_token!
    raw_token = SecureRandom.urlsafe_base64(24)

    update!(
      telegram_connection_token_digest: self.class.digest_telegram_connection_token(raw_token),
      telegram_connection_token_generated_at: Time.current
    )

    raw_token
  end

  def complete_telegram_connection!(chat_id:)
    update!(
      telegram_chat_id: chat_id,
      telegram_connected_at: Time.current,
      telegram_connection_token_digest: nil,
      telegram_connection_token_generated_at: nil
    )
  end

  def disconnect_telegram!
    update!(
      telegram_chat_id: nil,
      telegram_connected_at: nil,
      telegram_connection_token_digest: nil,
      telegram_connection_token_generated_at: nil
    )
  end

  def self.find_by_telegram_connection_token(raw_token)
    token_digest = digest_telegram_connection_token(raw_token)
    return if token_digest.blank?

    where(telegram_connection_token_digest: token_digest)
      .where(telegram_connection_token_generated_at: TELEGRAM_CONNECTION_TOKEN_TTL.ago..)
      .first
  end

  def self.digest_telegram_connection_token(raw_token)
    normalized_token = raw_token.to_s.strip
    return if normalized_token.blank?

    Digest::SHA256.hexdigest(normalized_token)
  end

  def self.sample_from(characters)
    characters[SecureRandom.random_number(characters.length)]
  end
  private_class_method :sample_from
end
