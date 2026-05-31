# frozen_string_literal: true

class AddPinnedToBuckets < ActiveRecord::Migration[8.1]
  def change
    add_column :buckets, :pinned, :boolean, default: false, null: false
    add_index :buckets, [ :user_id, :pinned ]
  end
end
