# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_21_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "app_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "telegram_api_key"
    t.datetime "updated_at", null: false
  end

  create_table "partners", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_partners_on_deleted_at"
    t.index ["name"], name: "index_partners_on_name"
  end

  create_table "services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name", null: false
    t.bigint "partner_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_services_on_deleted_at"
    t.index ["partner_id"], name: "index_services_on_partner_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "member_id"
    t.string "name", null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_tasks_on_deleted_at"
    t.index ["member_id"], name: "index_tasks_on_member_id"
    t.index ["service_id"], name: "index_tasks_on_service_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email"
    t.datetime "last_login_at"
    t.string "name"
    t.string "password_digest"
    t.integer "role", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
  end

  add_foreign_key "services", "partners"
  add_foreign_key "tasks", "services"
  add_foreign_key "tasks", "users", column: "member_id"
end
