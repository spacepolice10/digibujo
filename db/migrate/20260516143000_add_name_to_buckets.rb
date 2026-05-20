# frozen_string_literal: true

class AddNameToBuckets < ActiveRecord::Migration[8.1]
  def up
    add_column :buckets, :name, :string

    execute <<~SQL.squish
      UPDATE buckets SET name = (
        SELECT name FROM projects WHERE projects.id = buckets.bucketable_id
      ) WHERE bucketable_type = 'Project'
    SQL

    execute <<~SQL.squish
      UPDATE buckets SET name = (
        SELECT name FROM collections WHERE collections.id = buckets.bucketable_id
      ) WHERE bucketable_type = 'Collection'
    SQL

    change_column_null :buckets, :name, false

    remove_column :projects, :name
    remove_column :collections, :name
  end

  def down
    add_column :projects, :name, :string
    add_column :collections, :name, :string

    execute <<~SQL.squish
      UPDATE projects SET name = (
        SELECT name FROM buckets
        WHERE buckets.bucketable_type = 'Project' AND buckets.bucketable_id = projects.id
        LIMIT 1
      )
    SQL

    execute <<~SQL.squish
      UPDATE collections SET name = (
        SELECT name FROM buckets
        WHERE buckets.bucketable_type = 'Collection' AND buckets.bucketable_id = collections.id
        LIMIT 1
      )
    SQL

    change_column_null :projects, :name, false
    change_column_null :collections, :name, false

    remove_column :buckets, :name
  end
end
