# frozen_string_literal: true

class CleanupOldTypes < ActiveRecord::Migration[8.1]
  def change
    drop_table :timespreads
    remove_column :buckets, :bucket_parent_id, :integer
  end
end
