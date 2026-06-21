# frozen_string_literal: true

class FlattenBundlesToCollections < ActiveRecord::Migration[8.1]
  class MigrationBucket < ApplicationRecord
    self.table_name = "buckets"
  end

  class MigrationCollection < ApplicationRecord
    self.table_name = "collections"
  end

  def up
    bundle_rows = select_all("SELECT id, user_id FROM bundles")

    bundle_rows.each do |row|
      bundle_id = row["id"]
      user_id = row["user_id"]
      old_bucket = MigrationBucket.find_by(bucketable_type: "Bundle", bucketable_id: bundle_id)
      next unless old_bucket

      collection = MigrationCollection.create!
      name = unique_bucket_name(user_id, old_bucket.name, exclude_bucket_id: old_bucket.id)
      new_bucket = MigrationBucket.create!(
        **bucket_attributes_from(old_bucket, user_id:, name:, collection_id: collection.id)
      )

      copy_side_note!(from_id: old_bucket.id, to_id: new_bucket.id)
      repoint_records!(old_bucket_id: old_bucket.id, new_bucket_id: new_bucket.id, user_id: user_id)

      delete_bucket!(old_bucket.id)
      execute "DELETE FROM bundles WHERE id = #{bundle_id}"
    end

    drop_table :bundles
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def bucket_attributes_from(old_bucket, user_id:, name:, collection_id:)
    attrs = {
      user_id: user_id,
      bucketable_type: "Collection",
      bucketable_id: collection_id,
      name: name,
      colour: old_bucket.colour,
      icon: old_bucket.icon
    }

    %w[pinned archived archives_on].each do |column|
      next unless bucket_column?(column)

      attrs[column.to_sym] = old_bucket.public_send(column)
    end

    attrs
  end

  def bucket_column?(column)
    MigrationBucket.column_names.include?(column)
  end

  def unique_bucket_name(user_id, desired_name, exclude_bucket_id: nil)
    base = desired_name.to_s.strip.downcase
    name = base
    counter = 2

    scope = MigrationBucket.where(user_id: user_id)
    scope = scope.where.not(id: exclude_bucket_id) if exclude_bucket_id

    while scope.where(name: name).exists?
      name = "#{base} #{counter}"
      counter += 1
    end

    name
  end

  def copy_side_note!(from_id:, to_id:)
    rich_text = ActionText::RichText.find_by(record_type: "Bucket", record_id: from_id, name: "side_note")
    return if rich_text.blank?

    ActionText::RichText.create!(
      record_type: "Bucket",
      record_id: to_id,
      name: "side_note",
      body: rich_text.body
    )
  end

  def repoint_records!(old_bucket_id:, new_bucket_id:, user_id:)
    execute <<~SQL.squish
      UPDATE bullets SET bucket_id = #{new_bucket_id} WHERE bucket_id = #{old_bucket_id}
    SQL

    execute <<~SQL.squish
      UPDATE pinned_entities
      SET pinnable_id = #{new_bucket_id}
      WHERE pinnable_type = 'Bucket' AND pinnable_id = #{old_bucket_id}
    SQL

    execute <<~SQL.squish
      UPDATE search_records
      SET searchable_id = #{new_bucket_id}
      WHERE searchable_type = 'Bucket' AND searchable_id = #{old_bucket_id}
    SQL

    execute <<~SQL.squish
      UPDATE search_selections
      SET searchable_id = #{new_bucket_id}
      WHERE searchable_type = 'Bucket' AND searchable_id = #{old_bucket_id}
    SQL

    execute <<~SQL.squish
      UPDATE activities
      SET subject_id = #{new_bucket_id}
      WHERE subject_type = 'Bucket' AND subject_id = #{old_bucket_id} AND user_id = #{user_id}
    SQL
  end

  def delete_bucket!(bucket_id)
    execute <<~SQL.squish
      DELETE FROM action_text_rich_texts
      WHERE record_type = 'Bucket' AND record_id = #{bucket_id}
    SQL
    execute "DELETE FROM buckets WHERE id = #{bucket_id}"
  end
end
