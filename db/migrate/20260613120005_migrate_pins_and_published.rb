# frozen_string_literal: true

class MigratePinsAndPublished < ActiveRecord::Migration[8.1]
  class MigrationPinnedEntity < ApplicationRecord
    self.table_name = 'pinned_entities'
  end

  class MigrationPublishedEntity < ApplicationRecord
    self.table_name = 'published_entities'
  end

  class MigrationBullet < ApplicationRecord
    self.table_name = 'bullets'
  end

  class MigrationProject < ApplicationRecord
    self.table_name = 'projects'
  end

  class MigrationBucket < ApplicationRecord
    self.table_name = 'buckets'
  end

  def up
    say_with_time 'Migrating pinned bullets' do
      MigrationBullet.where(pinned: true).find_each do |bullet|
        MigrationPinnedEntity.find_or_create_by!(
          user_id: bullet.user_id,
          pinnable_type: 'Bullet',
          pinnable_id: bullet.id,
          position: 0
        )
      end
    end

    say_with_time 'Migrating pinned projects' do
      MigrationProject.where(pinned: true).find_each do |project|
        MigrationPinnedEntity.find_or_create_by!(
          user_id: project.user_id,
          pinnable_type: 'Project',
          pinnable_id: project.id,
          position: 0
        )
      end
    end

    say_with_time 'Migrating pinned buckets' do
      MigrationBucket.where(pinned: true).find_each do |bucket|
        MigrationPinnedEntity.find_or_create_by!(
          user_id: bucket.user_id,
          pinnable_type: 'Bucket',
          pinnable_id: bucket.id,
          position: 0
        )
      end
    end

    say_with_time 'Migrating published bullets' do
      MigrationBullet.where.not(public_code: nil).find_each do |bullet|
        MigrationPublishedEntity.find_or_create_by!(
          user_id: bullet.user_id,
          publishable_type: 'Bullet',
          publishable_id: bullet.id
        ) do |pe|
          pe.code = bullet.public_code
          pe.published_at = bullet.updated_at
        end
      end
    end
  end

  def down
    MigrationPinnedEntity.delete_all
    MigrationPublishedEntity.delete_all
  end
end
