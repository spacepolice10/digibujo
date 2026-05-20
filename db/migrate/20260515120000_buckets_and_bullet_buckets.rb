# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- one-shot schema migration
class BucketsAndBulletBuckets < ActiveRecord::Migration[8.1]
  def up
    create_table :buckets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :bucketable_type, null: false
      t.integer :bucketable_id, null: false
      t.timestamps
    end
    add_index :buckets, %i[bucketable_type bucketable_id], unique: true

    create_table :collections do |t|
      t.string :name, null: false
      t.string :colour
      t.timestamps
    end

    create_table :bullet_buckets do |t|
      t.references :bullet, null: false, foreign_key: true
      t.references :bucket, null: false, foreign_key: true
      t.timestamps
    end
    add_index :bullet_buckets, %i[bullet_id bucket_id], unique: true

    execute <<~SQL.squish
      INSERT INTO buckets (user_id, bucketable_type, bucketable_id, created_at, updated_at)
      SELECT user_id, 'Project', id, datetime('now'), datetime('now') FROM projects
    SQL

    execute <<~SQL.squish
      INSERT INTO bullet_buckets (bullet_id, bucket_id, created_at, updated_at)
      SELECT bullets.id, buckets.id, datetime('now'), datetime('now')
      FROM bullets
      INNER JOIN buckets ON buckets.bucketable_type = 'Project' AND buckets.bucketable_id = bullets.project_id
      WHERE bullets.project_id IS NOT NULL
    SQL

    remove_foreign_key :bullets, :projects
    remove_index :bullets, :project_id
    remove_column :bullets, :project_id

    remove_foreign_key :projects, :users
    remove_index :projects, name: 'index_projects_on_user_id'
    remove_index :projects, name: 'index_projects_on_user_id_and_name'
    remove_column :projects, :user_id

    remove_foreign_key :streams, :users
    drop_table :streams, if_exists: true
  end

  def down
    create_table :streams do |t|
      t.references :user, null: false, foreign_key: true
      t.json :fields, default: {}, null: false
      t.string :name
      t.timestamps
    end

    add_reference :projects, :user, null: true, foreign_key: true
    add_reference :bullets, :project, null: true, foreign_key: true

    execute <<~SQL.squish
      UPDATE projects SET user_id = (
        SELECT user_id FROM buckets WHERE buckets.bucketable_type = 'Project' AND buckets.bucketable_id = projects.id LIMIT 1
      )
    SQL

    execute <<~SQL.squish
      UPDATE bullets SET project_id = (
        SELECT buckets.bucketable_id FROM bullet_buckets
        INNER JOIN buckets ON buckets.id = bullet_buckets.bucket_id
        WHERE bullet_buckets.bullet_id = bullets.id
        AND buckets.bucketable_type = 'Project'
        LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1 FROM bullet_buckets WHERE bullet_buckets.bullet_id = bullets.id
      )
    SQL

    change_column_null :projects, :user_id, false
    add_index :projects, :user_id
    add_index :projects, %i[user_id name], unique: true

    drop_table :bullet_buckets
    drop_table :buckets
    drop_table :collections
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
