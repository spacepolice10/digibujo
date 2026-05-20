# frozen_string_literal: true

class AddIdentityToBuckets < ActiveRecord::Migration[8.1]
  def up
    add_column :buckets, :colour, :string
    add_column :buckets, :icon, :string

    execute <<~SQL.squish
      UPDATE buckets SET colour = (
        SELECT colour FROM projects WHERE projects.id = buckets.bucketable_id
      ) WHERE bucketable_type = 'Project'
    SQL

    execute <<~SQL.squish
      UPDATE buckets SET colour = (
        SELECT colour FROM collections WHERE collections.id = buckets.bucketable_id
      ) WHERE bucketable_type = 'Collection'
    SQL

    remove_column :projects, :colour
    remove_column :collections, :colour
  end

  def down
    add_column :projects, :colour, :string
    add_column :collections, :colour, :string

    execute <<~SQL.squish
      UPDATE projects SET colour = (
        SELECT colour FROM buckets
        WHERE buckets.bucketable_type = 'Project' AND buckets.bucketable_id = projects.id
        LIMIT 1
      )
    SQL

    execute <<~SQL.squish
      UPDATE collections SET colour = (
        SELECT colour FROM buckets
        WHERE buckets.bucketable_type = 'Collection' AND buckets.bucketable_id = collections.id
        LIMIT 1
      )
    SQL

    remove_column :buckets, :icon
    remove_column :buckets, :colour
  end
end
