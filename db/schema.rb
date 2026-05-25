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

ActiveRecord::Schema[8.1].define(version: 2026_05_21_130000) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "buckets", force: :cascade do |t|
    t.integer "bucketable_id", null: false
    t.string "bucketable_type", null: false
    t.string "colour"
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["bucketable_type", "bucketable_id"], name: "index_buckets_on_bucketable_type_and_bucketable_id", unique: true
    t.index ["user_id"], name: "index_buckets_on_user_id"
  end

  create_table "bullet_activities", force: :cascade do |t|
    t.string "action", null: false
    t.integer "bullet_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["bullet_id", "created_at"], name: "index_bullet_activities_on_bullet_id_and_created_at"
    t.index ["user_id", "created_at"], name: "index_bullet_activities_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_bullet_activities_on_user_id"
  end

  create_table "bullets", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.date "archives_on"
    t.integer "bucket_id"
    t.integer "bulletable_id", null: false
    t.string "bulletable_type", null: false
    t.integer "context_bullet_id"
    t.datetime "created_at", null: false
    t.date "ends_date"
    t.boolean "pinned", default: false, null: false
    t.date "pops_on"
    t.string "public_code"
    t.datetime "triaged_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["bucket_id"], name: "index_bullets_on_bucket_id"
    t.index ["bulletable_type", "bulletable_id"], name: "index_bullets_on_bulletable"
    t.index ["context_bullet_id"], name: "index_bullets_on_context_bullet_id"
    t.index ["public_code"], name: "index_bullets_on_public_code", unique: true
    t.index ["user_id", "archived"], name: "index_bullets_on_user_id_and_archived"
    t.index ["user_id", "archives_on"], name: "index_bullets_on_user_id_and_archives_on"
    t.index ["user_id", "pinned"], name: "index_bullets_on_user_id_and_pinned"
    t.index ["user_id", "pops_on"], name: "index_bullets_on_user_id_and_pops_on"
    t.index ["user_id", "triaged_at"], name: "index_bullets_on_user_id_and_triaged_at"
    t.index ["user_id"], name: "index_bullets_on_user_id"
    t.index ["user_id"], name: "index_bullets_on_user_id_and_status"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
  end

  create_table "login_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_login_codes_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.boolean "done", default: false, null: false
    t.datetime "done_at"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "buckets", "users"
  add_foreign_key "bullet_activities", "users"
  add_foreign_key "bullets", "buckets"
  add_foreign_key "bullets", "bullets", column: "context_bullet_id", on_delete: :nullify
  add_foreign_key "bullets", "users"
  add_foreign_key "login_codes", "users"
  add_foreign_key "sessions", "users"
end
