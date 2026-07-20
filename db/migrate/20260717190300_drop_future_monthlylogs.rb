# frozen_string_literal: true

class DropFutureMonthlylogs < ActiveRecord::Migration[8.1]
  class MigrationBucket < ActiveRecord::Base
    self.table_name = 'buckets'
  end

  class MigrationBullet < ActiveRecord::Base
    self.table_name = 'bullets'
  end

  class MigrationFuture < ActiveRecord::Base
    self.table_name = 'futures'
  end

  def up
    return unless table_exists?(:future_monthlylogs)

    MigrationBucket.where(bucketable_type: 'FutureMonthlylog').find_each do |slot_bucket|
      future_id = connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([
          'SELECT future_id FROM future_monthlylogs WHERE id = ?',
          slot_bucket.bucketable_id
        ])
      )
      future = MigrationFuture.find_by(id: future_id)
      future_bucket = future && MigrationBucket.find_by(bucketable_type: 'Future', bucketable_id: future.id)

      pops_on = begin
        Date.parse("1 #{slot_bucket.name}")
      rescue Date::Error, ArgumentError
        nil
      end

      if future_bucket
        MigrationBullet.where(bucket_id: slot_bucket.id).update_all(
          bucket_id: future_bucket.id,
          pops_on: pops_on,
          updated_at: Time.current
        )
      end

      slot_bucket.destroy!
    end

    drop_table :future_monthlylogs
  end

  def down
    create_table :future_monthlylogs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :future, null: false, foreign_key: true
      t.timestamps
    end
  end
end
