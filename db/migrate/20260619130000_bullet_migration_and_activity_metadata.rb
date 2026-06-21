# frozen_string_literal: true

class BulletMigrationAndActivityMetadata < ActiveRecord::Migration[8.1]
  def change
    change_table :bullets, bulk: true do |t|
      t.remove :triaged_at, type: :datetime
      t.datetime :migrated_at
      t.json :last_migration, null: false, default: {}
    end

    remove_index :bullets, name: "index_bullets_on_user_id_and_triaged_at", if_exists: true
    add_index :bullets, %i[user_id migrated_at]

    change_table :bullet_activities, bulk: true do |t|
      t.json :metadata, null: false, default: {}
    end
  end
end
