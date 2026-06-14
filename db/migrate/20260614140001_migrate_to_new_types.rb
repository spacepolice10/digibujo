class MigrateToNewTypes < ActiveRecord::Migration[8.1]
  def up
    # 1. Find the "Future Log" root Collection bucket
    future_log_bucket = Bucket.find_by(
      bucketable_type: 'Collection',
      bucket_parent_id: nil,
      name: 'future log'
    )

    if future_log_bucket
      future_bucket = FutureBucket.create!(user_id: future_log_bucket.user_id)
      future_log_bucket.update!(
        bucketable_type: 'FutureBucket',
        bucketable_id: future_bucket.id
      )

      # 2. Migrate child TimeSpread buckets to MonthlyBucket
      child_buckets = Bucket.where(bucket_parent_id: future_log_bucket.id, bucketable_type: 'TimeSpread')
      child_buckets.each do |child_bucket|
        time_spread = child_bucket.bucketable
        monthly_bucket = MonthlyBucket.create!(
          user_id: future_log_bucket.user_id,
          future_bucket_id: future_bucket.id,
          period_from: time_spread.period_from,
          period_to: time_spread.period_to
        )
        child_bucket.update!(
          bucketable_type: 'MonthlyBucket',
          bucketable_id: monthly_bucket.id
        )
        time_spread.destroy!
      end

      # 3. Find "Year Goals" child Collection → reassign bullets to FutureBucket
      year_goals_bucket = Bucket.find_by(
        bucket_parent_id: future_log_bucket.id,
        bucketable_type: 'Collection',
        name: 'year goals'
      )

      if year_goals_bucket
        Bullet.where(bucket_id: year_goals_bucket.id).update_all(bucket_id: future_log_bucket.id)
        year_goals_bucket.bucketable.destroy!
        year_goals_bucket.destroy!
      end
    end

    # 4. Migrate standalone TimeSpread buckets (no parent) to MonthlyBucket
    Bucket.where(bucketable_type: 'TimeSpread').find_each do |bucket|
      time_spread = bucket.bucketable
      monthly_bucket = MonthlyBucket.create!(
        user_id: bucket.user_id,
        period_from: time_spread.period_from,
        period_to: time_spread.period_to
      )
      bucket.update!(
        bucketable_type: 'MonthlyBucket',
        bucketable_id: monthly_bucket.id
      )
      time_spread.destroy!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
