# frozen_string_literal: true

# puts 'Bắt đầu tạo lượng dữ liệu khổng lồ (Massive Seeding)...'
# now = Time.current

# # --- 1. Users ---
# admin_email = 'admin@blueprint.com'
# unless User.exists?(email: admin_email)
#   User.create!(
#     email: admin_email,
#     name: 'System Admin',
#     password: 'Password123@',
#     role: :admin
#   )
# end

# member_emails = (1..100).map { |i| "member#{i}@blueprint.com" }
# existing_members = User.where(email: member_emails).pluck(:email)
# missing_members = member_emails - existing_members

# if missing_members.any?
#   password_digest = BCrypt::Password.create('Password123@')

#   users_data = missing_members.map.with_index do |email, i|
#     {
#       email: email,
#       name: "Member #{existing_members.size + i + 1}",
#       password_digest: password_digest,
#       role: 1, # member
#       created_at: now,
#       updated_at: now
#     }
#   end
#   User.insert_all(users_data)
# end
# member_ids = User.where(role: :member).pluck(:id)
# puts "- Đã hoàn thành xử lý #{User.count} Users."

# # --- 2. Partners ---
# puts 'Đang xử lý Partners...'
# target_partners_count = 50
# current_partners_count = Partner.count

# if current_partners_count < target_partners_count
#   partners_data = ((current_partners_count + 1)..target_partners_count).map do |i|
#     {
#       name: "Partner #{i} - #{SecureRandom.hex(4)}",
#       created_at: now,
#       updated_at: now
#     }
#   end
#   Partner.insert_all(partners_data)
# end
# partner_ids = Partner.pluck(:id)
# puts "- Đã hoàn thành xử lý #{Partner.count} Partners."


# # --- 3. Services & Tasks ---
# puts 'Đang bổ sung Services và Tasks với số lượng lớn (Có thể mất vài giây)...'
# SERVICES_PER_PARTNER = 50
# TASKS_PER_SERVICE = 10

# partner_ids.each do |pid|
#   existing_services_count = Service.where(partner_id: pid).count
#   services_to_create = SERVICES_PER_PARTNER - existing_services_count

#   if services_to_create > 0
#     # Batch tạo services tránh trùng lặp tên bằng SecureRandom
#     services_data = services_to_create.times.map do |j|
#       {
#         name: "Svc #{SecureRandom.hex(6)} for P-#{pid}",
#         partner_id: pid,
#         created_at: now,
#         updated_at: now
#       }
#     end

#     # insert_all với returning: %i[id] để lấy được danh sách id vừa chèn
#     result = Service.insert_all(services_data, returning: %i[id])
#     new_service_ids = result.rows.flatten

#     # Chuẩn bị dữ liệu cho Tasks
#     tasks_data = []
#     new_service_ids.each do |sid|
#       TASKS_PER_SERVICE.times do |k|
#         tasks_data << {
#           name: "Task #{k + 1} của Svc-#{sid}",
#           service_id: sid,
#           member_id: member_ids.sample,
#           created_at: now,
#           updated_at: now
#         }
#       end
#     end

#     # Batch tạo tasks
#     Task.insert_all(tasks_data) if tasks_data.any?
#   end
# end

# puts "- Hiện tại database có #{Service.count} Services."
# puts "- Hiện tại database có #{Task.count} Tasks."
# puts "🎉 Hoàn tất Seeding thành công !"
