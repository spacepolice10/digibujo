# frozen_string_literal: true

class RenameFuturesMonthlylogsAndDetach < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :monthly_buckets, :future_buckets if foreign_key_exists?(:monthly_buckets, :future_buckets)
    remove_index :monthly_buckets, :future_bucket_id if index_exists?(:monthly_buckets, :future_bucket_id)
    remove_column :monthly_buckets, :future_bucket_id, :integer

    rename_table :future_buckets, :futures
    rename_table :monthly_buckets, :monthlylogs

    execute <<~SQL.squish
      UPDATE buckets SET bucketable_type = 'Future' WHERE bucketable_type = 'FutureBucket'
    SQL
    execute <<~SQL.squish
      UPDATE buckets SET bucketable_type = 'Monthlylog' WHERE bucketable_type = 'MonthlyBucket'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE buckets SET bucketable_type = 'FutureBucket' WHERE bucketable_type = 'Future'
    SQL
    execute <<~SQL.squish
      UPDATE buckets SET bucketable_type = 'MonthlyBucket' WHERE bucketable_type = 'Monthlylog'
    SQL

    rename_table :futures, :future_buckets
    rename_table :monthlylogs, :monthly_buckets

    add_reference :monthly_buckets, :future_bucket, foreign_key: { to_table: :future_buckets }
    # Cannot reliably restore future_bucket_id values
  end
end
