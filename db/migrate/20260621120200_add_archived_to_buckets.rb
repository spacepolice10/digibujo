# frozen_string_literal: true

class AddArchivedToBuckets < ActiveRecord::Migration[8.1]
  def change
    add_column :buckets, :archived, :boolean, default: false, null: false
    add_column :buckets, :archives_on, :date
    add_index :buckets, %i[user_id archived]
  end
end
