# frozen_string_literal: true

class RenameParentToBucketParentOnBuckets < ActiveRecord::Migration[8.1]
  def change
    rename_column :buckets, :parent_id, :bucket_parent_id
    rename_index :buckets, 'index_buckets_on_parent_id', 'index_buckets_on_bucket_parent_id'
  end
end
