# frozen_string_literal: true

class MoveDescriptionFromBucketsToCollections < ActiveRecord::Migration[8.1]
  def up
    add_column :collections, :description, :text

    execute <<~SQL.squish
      UPDATE collections
      SET description = (
        SELECT buckets.description
        FROM buckets
        WHERE buckets.bucketable_type = 'Collection'
          AND buckets.bucketable_id = collections.id
      )
      WHERE EXISTS (
        SELECT 1
        FROM buckets
        WHERE buckets.bucketable_type = 'Collection'
          AND buckets.bucketable_id = collections.id
          AND buckets.description IS NOT NULL
      )
    SQL

    remove_column :buckets, :description
  end

  def down
    add_column :buckets, :description, :text

    execute <<~SQL.squish
      UPDATE buckets
      SET description = (
        SELECT collections.description
        FROM collections
        WHERE buckets.bucketable_type = 'Collection'
          AND buckets.bucketable_id = collections.id
      )
      WHERE buckets.bucketable_type = 'Collection'
        AND EXISTS (
          SELECT 1
          FROM collections
          WHERE buckets.bucketable_id = collections.id
            AND collections.description IS NOT NULL
        )
    SQL

    remove_column :collections, :description
  end
end
