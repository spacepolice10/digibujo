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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_120000) do
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

  create_table "activities", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["subject_type", "subject_id", "created_at"], name: "index_activities_on_subject_type_and_subject_id_and_created_at"
    t.index ["user_id", "created_at"], name: "index_activities_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "archives", force: :cascade do |t|
    t.integer "archivable_id", null: false
    t.string "archivable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["archivable_type", "archivable_id"], name: "index_archives_on_archivable"
    t.index ["archivable_type", "archivable_id"], name: "index_archives_on_archivable_type_and_archivable_id", unique: true
    t.index ["archivable_type"], name: "index_archives_on_archivable_type"
    t.index ["user_id"], name: "index_archives_on_user_id"
  end

  create_table "auth_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_auth_codes_on_user_id"
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
    t.integer "bucket_id", null: false
    t.integer "bulletable_id", null: false
    t.string "bulletable_type", null: false
    t.datetime "created_at", null: false
    t.json "last_migration", default: {}, null: false
    t.datetime "migrated_at"
    t.date "pops_on"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["bucket_id"], name: "index_bullets_on_bucket_id"
    t.index ["bulletable_type", "bulletable_id"], name: "index_bullets_on_bulletable"
    t.index ["user_id", "migrated_at"], name: "index_bullets_on_user_id_and_migrated_at"
    t.index ["user_id", "pops_on"], name: "index_bullets_on_user_id_and_pops_on"
    t.index ["user_id"], name: "index_bullets_on_user_id"
    t.index ["user_id"], name: "index_bullets_on_user_id_and_pinned"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "updated_at", null: false
  end

  create_table "daylog_mood_entities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "daylog_id", null: false
    t.integer "mood", null: false
    t.datetime "updated_at", null: false
    t.index ["daylog_id", "date"], name: "index_daylog_mood_entities_on_daylog_id_and_date", unique: true
    t.index ["daylog_id"], name: "index_daylog_mood_entities_on_daylog_id"
  end

  create_table "daylog_pictures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "daylog_id", null: false
    t.datetime "updated_at", null: false
    t.index ["daylog_id", "date"], name: "index_daylog_pictures_on_daylog_id_and_date", unique: true
    t.index ["daylog_id"], name: "index_daylog_pictures_on_daylog_id"
  end

  create_table "daylogs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_daylogs_on_user_id", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.date "ends_date"
    t.date "starts_date"
  end

  create_table "futures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "period_from", null: false
    t.date "period_to", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "period_from"], name: "index_futures_on_user_id_and_period_from", unique: true
    t.index ["user_id"], name: "index_futures_on_user_id"
  end

  create_table "monthlylogs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "period_from"
    t.date "period_to"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "period_from"], name: "index_monthlylogs_on_user_id_and_period_from", unique: true
    t.index ["user_id"], name: "index_monthlylogs_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
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
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_projects_on_user_id_and_kind_and_name", unique: true
    t.index ["user_id", "name"], name: "index_projects_on_user_id_and_name", unique: true
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

  create_table "search_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "search_body"
    t.string "search_name"
    t.integer "searchable_id", null: false
    t.string "searchable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "searchable_type", "searchable_id"], name: "index_search_records_on_user_and_searchable", unique: true
    t.index ["user_id"], name: "index_search_records_on_user_id"
  end

  create_table "search_selections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "query"
    t.integer "searchable_id", null: false
    t.string "searchable_type", null: false
    t.datetime "selected_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_search_selections_on_searchable"
    t.index ["user_id", "searchable_type", "searchable_id"], name: "index_search_selections_on_user_and_searchable", unique: true
    t.index ["user_id", "selected_at"], name: "index_search_selections_on_user_id_and_selected_at"
    t.index ["user_id"], name: "index_search_selections_on_user_id"
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
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
  end

  create_table "tracker_completions", force: :cascade do |t|
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "tracker_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tracker_id", "date"], name: "index_tracker_completions_on_tracker_id_and_date", unique: true
    t.index ["tracker_id"], name: "index_tracker_completions_on_tracker_id"
  end

  create_table "trackers", force: :cascade do |t|
    t.string "colour"
    t.datetime "created_at", null: false
    t.string "icon"
    t.integer "monthlylog_id", null: false
    t.string "name", null: false
    t.json "schedule", default: {"days" => [0, 1, 2, 3, 4, 5, 6]}, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_trackers_on_user_id_and_created_at"
    t.index ["monthlylog_id"], name: "index_trackers_on_monthlylog_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.string "appearance", default: "default", null: false
    t.boolean "archived_expanded", default: true, null: false
    t.boolean "collections_expanded", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "logs_expanded", default: true, null: false
    t.boolean "projects_expanded", default: true, null: false
    t.boolean "published_expanded", default: true, null: false
    t.boolean "spreads_expanded", default: true, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "onboarded", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "voices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "archives", "users"
  add_foreign_key "auth_codes", "users"
  add_foreign_key "buckets", "users"
  add_foreign_key "bullet_projects", "bullets"
  add_foreign_key "bullet_projects", "projects"
  add_foreign_key "bullets", "buckets"
  add_foreign_key "bullets", "users"
  add_foreign_key "daylog_mood_entities", "daylogs"
  add_foreign_key "daylog_pictures", "daylogs"
  add_foreign_key "daylogs", "users"
  add_foreign_key "futures", "users"
  add_foreign_key "monthlylogs", "users"
  add_foreign_key "pinned_entities", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "published_entities", "users"
  add_foreign_key "search_records", "users"
  add_foreign_key "search_selections", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "tracker_completions", "trackers"
  add_foreign_key "trackers", "monthlylogs"
  add_foreign_key "user_settings", "users"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "search_records_fts", "fts5", [" search_name", "search_body", "tokenize='unicode61 remove_diacritics 2'", "prefix='2 3 4 5' "]
end
