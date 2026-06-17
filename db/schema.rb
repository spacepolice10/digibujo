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

ActiveRecord::Schema[8.1].define(version: 2026_06_17_000001) do
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
    t.boolean "pinned", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["bucketable_type", "bucketable_id"], name: "index_buckets_on_bucketable_type_and_bucketable_id", unique: true
    t.index ["user_id", "pinned"], name: "index_buckets_on_user_id_and_pinned"
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

  create_table "bullet_people", force: :cascade do |t|
    t.integer "bullet_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "person_id", null: false
    t.index ["bullet_id", "person_id"], name: "index_bullet_people_on_bullet_id_and_person_id", unique: true
    t.index ["bullet_id"], name: "index_bullet_people_on_bullet_id"
    t.index ["person_id"], name: "index_bullet_people_on_person_id"
  end

  create_table "bullet_projects", force: :cascade do |t|
    t.integer "bullet_id", null: false
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["bullet_id", "project_id"], name: "index_bullet_projects_on_bullet_id_and_project_id", unique: true
    t.index ["bullet_id"], name: "index_bullet_projects_on_bullet_id"
    t.index ["project_id"], name: "index_bullet_projects_on_project_id"
  end

  create_table "bullets", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.date "archives_on"
    t.integer "bucket_id"
    t.integer "bulletable_id", null: false
    t.string "bulletable_type", null: false
    t.datetime "created_at", null: false
    t.date "ends_date"
    t.date "pops_on"
    t.datetime "triaged_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["bucket_id"], name: "index_bullets_on_bucket_id"
    t.index ["bulletable_type", "bulletable_id"], name: "index_bullets_on_bulletable"
    t.index ["user_id", "archived"], name: "index_bullets_on_user_id_and_archived"
    t.index ["user_id", "archives_on"], name: "index_bullets_on_user_id_and_archives_on"
    t.index ["user_id", "pops_on"], name: "index_bullets_on_user_id_and_pops_on"
    t.index ["user_id", "triaged_at"], name: "index_bullets_on_user_id_and_triaged_at"
    t.index ["user_id"], name: "index_bullets_on_user_id"
    t.index ["user_id"], name: "index_bullets_on_user_id_and_pinned"
    t.index ["user_id"], name: "index_bullets_on_user_id_and_status"
  end

  create_table "bundles", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["collection_id"], name: "index_bundles_on_collection_id"
    t.index ["user_id"], name: "index_bundles_on_user_id"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
  end

  create_table "future_buckets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_future_buckets_on_user_id"
  end

  create_table "login_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_login_codes_on_user_id"
  end

  create_table "monthly_buckets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "future_bucket_id"
    t.date "period_from"
    t.date "period_to"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["future_bucket_id"], name: "index_monthly_buckets_on_future_bucket_id"
    t.index ["user_id"], name: "index_monthly_buckets_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
    t.boolean "awaits_research", default: false, null: false
    t.boolean "idea", default: false, null: false
    t.integer "mood"
  end

  create_table "people", force: :cascade do |t|
    t.string "colour"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "icon"
    t.string "name", null: false
    t.string "number"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_people_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_people_on_user_id"
  end

  create_table "pinned_entities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "pinnable_id", null: false
    t.string "pinnable_type", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["pinnable_type", "pinnable_id"], name: "index_pinned_entities_on_pinnable"
    t.index ["user_id", "pinnable_type", "pinnable_id"], name: "idx_pinned_entities_on_user_and_pinnable", unique: true
    t.index ["user_id", "position"], name: "index_pinned_entities_on_user_id_and_position"
    t.index ["user_id"], name: "index_pinned_entities_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "colour"
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "published_entities", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "publishable_id", null: false
    t.string "publishable_type", null: false
    t.datetime "published_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["code"], name: "index_published_entities_on_code", unique: true
    t.index ["publishable_type", "publishable_id"], name: "index_published_entities_on_publishable"
    t.index ["user_id", "publishable_type", "publishable_id"], name: "idx_published_on_user_and_publishable", unique: true
    t.index ["user_id"], name: "index_published_entities_on_user_id"
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

  create_table "user_settings", force: :cascade do |t|
    t.boolean "collections_expanded", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "logs_expanded", default: true, null: false
    t.boolean "projects_expanded", default: true, null: false
    t.boolean "spreads_expanded", default: true, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id", unique: true
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
  add_foreign_key "bullet_people", "bullets"
  add_foreign_key "bullet_people", "people"
  add_foreign_key "bullet_projects", "bullets"
  add_foreign_key "bullet_projects", "projects"
  add_foreign_key "bullets", "buckets"
  add_foreign_key "bullets", "users"
  add_foreign_key "bundles", "collections"
  add_foreign_key "bundles", "users"
  add_foreign_key "future_buckets", "users"
  add_foreign_key "login_codes", "users"
  add_foreign_key "monthly_buckets", "future_buckets"
  add_foreign_key "monthly_buckets", "users"
  add_foreign_key "people", "users"
  add_foreign_key "pinned_entities", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "published_entities", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_settings", "users"
end
