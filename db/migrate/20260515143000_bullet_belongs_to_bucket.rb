# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- one-shot schema migration
class BulletBelongsToBucket < ActiveRecord::Migration[8.1]
  def up
    add_reference :bullets, :bucket, null: true, foreign_key: { to_table: :buckets }

    execute <<~SQL.squish
      UPDATE bullets SET bucket_id = (
        SELECT bb.bucket_id FROM bullet_buckets bb
        INNER JOIN buckets b ON b.id = bb.bucket_id
        WHERE bb.bullet_id = bullets.id
        ORDER BY CASE WHEN b.bucketable_type = 'Collection' THEN 0 ELSE 1 END, bb.id
        LIMIT 1
      )
      WHERE EXISTS (SELECT 1 FROM bullet_buckets bb WHERE bb.bullet_id = bullets.id)
    SQL

    drop_table :bullet_buckets
  end

  def down
    create_table :bullet_buckets do |t|
      t.references :bullet, null: false, foreign_key: true
      t.references :bucket, null: false, foreign_key: true
      t.timestamps
    end
    add_index :bullet_buckets, %i[bullet_id bucket_id], unique: true

    execute <<~SQL.squish
      INSERT INTO bullet_buckets (bullet_id, bucket_id, created_at, updated_at)
      SELECT id, bucket_id, datetime('now'), datetime('now') FROM bullets
      WHERE bucket_id IS NOT NULL
    SQL

    remove_reference :bullets, :bucket, foreign_key: true
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
