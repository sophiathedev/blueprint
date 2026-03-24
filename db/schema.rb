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

ActiveRecord::Schema[8.1].define(version: 2026_03_24_133000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "app_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "google_sheets_cancel_requested", default: false, null: false
    t.string "google_sheets_current_job_id"
    t.boolean "google_sheets_enabled", default: false, null: false
    t.text "google_sheets_last_sync_error"
    t.string "google_sheets_last_sync_status"
    t.datetime "google_sheets_last_synced_at"
    t.datetime "google_sheets_next_sync_at"
    t.string "google_sheets_next_sync_job_id"
    t.string "google_sheets_spreadsheet_id"
    t.integer "google_sheets_sync_interval_unit"
    t.integer "google_sheets_sync_interval_value"
    t.integer "google_sheets_sync_progress", default: 0, null: false
    t.string "google_sheets_tab_prefix"
    t.string "telegram_api_key"
    t.datetime "updated_at", null: false
  end

  create_table "order_services", force: :cascade do |t|
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.string "deadline_check_job_id"
    t.datetime "deleted_at"
    t.text "notes"
    t.string "partner_assignee_name"
    t.integer "priority_status"
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deadline_check_job_id"], name: "index_order_services_on_deadline_check_job_id"
    t.index ["deleted_at"], name: "index_order_services_on_deleted_at"
    t.index ["service_id"], name: "index_order_services_on_service_id"
  end

  create_table "order_tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.boolean "is_completed", default: false, null: false
    t.boolean "is_overdue", default: false, null: false
    t.datetime "mark_completed_at"
    t.bigint "order_service_id", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_order_tasks_on_deleted_at"
    t.index ["order_service_id", "task_id"], name: "index_order_tasks_on_order_service_id_and_task_id", unique: true
    t.index ["order_service_id"], name: "index_order_tasks_on_order_service_id"
    t.index ["task_id"], name: "index_order_tasks_on_task_id"
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
    t.bigint "telegram_chat_id"
    t.datetime "telegram_connected_at"
    t.string "telegram_connection_token_digest"
    t.datetime "telegram_connection_token_generated_at"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["telegram_chat_id"], name: "index_users_on_telegram_chat_id", unique: true
    t.index ["telegram_connection_token_digest"], name: "index_users_on_telegram_connection_token_digest", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "order_services", "services"
  add_foreign_key "order_tasks", "order_services"
  add_foreign_key "order_tasks", "tasks"
  add_foreign_key "services", "partners"
  add_foreign_key "tasks", "services"
  add_foreign_key "tasks", "users", column: "member_id"
end
