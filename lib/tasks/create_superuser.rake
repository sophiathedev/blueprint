# frozen_string_literal: true

require 'io/console'
require 'securerandom'

desc 'Create a superuser from terminal'
task create_superuser: :environment do
  to_utf8 = lambda do |value|
    value
      .to_s
      .dup
      .force_encoding(Encoding::UTF_8)
      .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '')
      .strip
  end

  print 'Nhập email: '
  email = to_utf8.call($stdin.gets)

  password = SecureRandom.base58(16)

  user = User.new(
    name: nil,
    email: email,
    password: password,
    password_confirmation: password,
    role: :admin
  )

  if user.save
    puts "Tạo superuser thành công: #{user.email}"
    puts "Mật khẩu tạm thời: #{password}"
  else
    puts 'Không thể tạo superuser:'
    user.errors.full_messages.each do |message|
      puts "- #{message}"
    end
  end
end
