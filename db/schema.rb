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

ActiveRecord::Schema[8.1].define(version: 2026_05_01_015500) do
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

  create_table "bullets", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.date "archives_on"
    t.integer "bulletable_id", null: false
    t.string "bulletable_type", null: false
    t.integer "context_bullet_id"
    t.datetime "created_at", null: false
    t.boolean "done", default: false, null: false
    t.datetime "done_at"
    t.date "ends_date"
    t.boolean "pinned", default: false, null: false
    t.integer "project_id"
    t.string "public_code"
    t.date "scheduled_on"
    t.datetime "triaged_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["bulletable_type", "bulletable_id"], name: "index_bullets_on_bulletable"
    t.index ["context_bullet_id"], name: "index_bullets_on_context_bullet_id"
    t.index ["project_id"], name: "index_bullets_on_project_id"
    t.index ["public_code"], name: "index_bullets_on_public_code", unique: true
    t.index ["user_id", "archived"], name: "index_bullets_on_user_id_and_archived"
    t.index ["user_id", "archives_on"], name: "index_bullets_on_user_id_and_archives_on"
    t.index ["user_id", "done"], name: "index_bullets_on_user_id_and_done"
    t.index ["user_id", "pinned"], name: "index_bullets_on_user_id_and_pinned"
    t.index ["user_id", "scheduled_on"], name: "index_bullets_on_user_id_and_scheduled_on"
    t.index ["user_id", "triaged_at"], name: "index_bullets_on_user_id_and_triaged_at"
    t.index ["user_id"], name: "index_bullets_on_user_id"
    t.index ["user_id"], name: "index_bullets_on_user_id_and_status"
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

  create_table "playlist_cards", force: :cascade do |t|
    t.integer "bullet_id", null: false
    t.datetime "created_at", null: false
    t.integer "playlist_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["bullet_id"], name: "index_playlist_cards_on_bullet_id"
    t.index ["playlist_id", "bullet_id"], name: "index_playlist_cards_on_playlist_id_and_bullet_id", unique: true
    t.index ["playlist_id", "position"], name: "index_playlist_cards_on_playlist_id_and_position"
    t.index ["playlist_id"], name: "index_playlist_cards_on_playlist_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.string "colour", null: false
    t.datetime "created_at", null: false
    t.string "icon", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "colour"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_projects_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "streams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "fields", default: {}, null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_streams_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bullets", "bullets", column: "context_bullet_id", on_delete: :nullify
  add_foreign_key "bullets", "projects"
  add_foreign_key "bullets", "users"
  add_foreign_key "login_codes", "users"
  add_foreign_key "playlist_cards", "bullets"
  add_foreign_key "playlist_cards", "playlists"
  add_foreign_key "playlists", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "streams", "users"
end
