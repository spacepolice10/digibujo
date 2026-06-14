# frozen_string_literal: true

class ProjectTags < ActiveRecord::Migration[8.1]
  class MigrationProject < ApplicationRecord
    self.table_name = "projects"
  end

  class MigrationBucket < ApplicationRecord
    self.table_name = "buckets"
  end

  class MigrationBullet < ApplicationRecord
    self.table_name = "bullets"
  end

  class MigrationBulletProject < ApplicationRecord
    self.table_name = "bullet_projects"
  end

  def up
    change_table :projects, bulk: true do |t|
      t.integer :user_id
      t.string :name
      t.string :colour
      t.string :icon
      t.boolean :pinned, default: false, null: false
    end

    create_table :bullet_projects do |t|
      t.references :bullet, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.timestamps
    end

    add_index :bullet_projects, %i[bullet_id project_id], unique: true

    migrate_project_buckets_to_tags

    change_column_null :projects, :user_id, false
    change_column_null :projects, :name, false
    add_foreign_key :projects, :users
    add_index :projects, :user_id

    delete_project_buckets
  end

  def down
    recreate_project_buckets_from_projects

    drop_table :bullet_projects

    remove_foreign_key :projects, :users
    change_table :projects, bulk: true do |t|
      t.remove :user_id
      t.remove :name
      t.remove :colour
      t.remove :icon
      t.remove :pinned
    end
  end

  private

  def migrate_project_buckets_to_tags
    say_with_time "Migrating project buckets to tags" do
      MigrationBucket.where(bucketable_type: "Project").find_each do |bucket|
        project = MigrationProject.find(bucket.bucketable_id)
        project.update!(
          user_id: bucket.user_id,
          name: bucket.name,
          colour: bucket.colour,
          icon: bucket.icon,
          pinned: bucket.pinned
        )

        bullet_ids = MigrationBullet.where(bucket_id: bucket.id).pluck(:id)
        next if bullet_ids.empty?

        now = Time.current
        rows = bullet_ids.map do |bullet_id|
          { bullet_id: bullet_id, project_id: project.id, created_at: now, updated_at: now }
        end
        MigrationBulletProject.insert_all(rows)

        MigrationBullet.where(id: bullet_ids).update_all(bucket_id: nil)
      end
    end
  end

  def delete_project_buckets
    say_with_time "Removing project buckets" do
      MigrationBucket.where(bucketable_type: "Project").delete_all
      MigrationProject.where(user_id: nil).delete_all
    end
  end

  def recreate_project_buckets_from_projects
    say_with_time "Recreating project buckets from projects" do
      MigrationProject.find_each do |project|
        bucket = MigrationBucket.create!(
          user_id: project.user_id,
          bucketable_type: "Project",
          bucketable_id: project.id,
          name: project.name,
          colour: project.colour,
          icon: project.icon,
          pinned: project.pinned
        )

        bullet_ids = MigrationBulletProject.where(project_id: project.id).pluck(:bullet_id)
        MigrationBullet.where(id: bullet_ids).update_all(bucket_id: bucket.id) if bullet_ids.any?
      end
    end
  end
end
