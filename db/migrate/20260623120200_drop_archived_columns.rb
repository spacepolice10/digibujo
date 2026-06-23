# frozen_string_literal: true

class DropArchivedColumns < ActiveRecord::Migration[8.1]
  def up
    remove_index :buckets, name: "index_buckets_on_user_id_and_archived"
    remove_column :buckets, :archived
    remove_column :buckets, :archives_on

    remove_index :bullets, name: "index_bullets_on_user_id_and_archived"
    remove_index :bullets, name: "index_bullets_on_user_id_and_archives_on"
    remove_index :bullets, name: "index_bullets_on_user_id_and_status"
    remove_column :bullets, :archived
    remove_column :bullets, :archives_on
  end

  def down
    add_column :buckets, :archived, :boolean, default: false, null: false
    add_column :buckets, :archives_on, :date
    add_index :buckets, %i[user_id archived]

    add_column :bullets, :archived, :boolean, default: false, null: false
    add_column :bullets, :archives_on, :date
    add_index :bullets, %i[user_id archived]
    add_index :bullets, %i[user_id archives_on]
    add_index :bullets, :user_id, name: "index_bullets_on_user_id_and_status"
  end
end