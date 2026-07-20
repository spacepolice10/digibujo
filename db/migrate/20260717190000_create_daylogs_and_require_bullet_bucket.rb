# frozen_string_literal: true

class CreateDaylogsAndRequireBulletBucket < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = 'users'
  end

  class MigrationDaylog < ApplicationRecord
    self.table_name = 'daylogs'
  end

  class MigrationBucket < ApplicationRecord
    self.table_name = 'buckets'
  end

  class MigrationBullet < ApplicationRecord
    self.table_name = 'bullets'
  end

  def up
    create_table :daylogs do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    MigrationUser.find_each do |user|
      daylog = MigrationDaylog.create!(user_id: user.id)
      bucket = MigrationBucket.create!(
        user_id: user.id,
        bucketable_type: 'Daylog',
        bucketable_id: daylog.id,
        name: 'daylog',
        icon: 'calendar'
      )
      MigrationBullet.where(user_id: user.id, bucket_id: nil, pops_on: nil)
                     .update_all(pops_on: Date.current)
      MigrationBullet.where(user_id: user.id, bucket_id: nil)
                     .update_all(bucket_id: bucket.id)
    end

    change_column_null :bullets, :bucket_id, false
  end

  def down
    change_column_null :bullets, :bucket_id, true

    MigrationBucket.where(bucketable_type: 'Daylog').find_each do |bucket|
      MigrationBullet.where(bucket_id: bucket.id).update_all(bucket_id: nil)
      bucket.destroy!
    end

    drop_table :daylogs
  end
end
