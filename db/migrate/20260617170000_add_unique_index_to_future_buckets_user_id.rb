# frozen_string_literal: true

class AddUniqueIndexToFutureBucketsUserId < ActiveRecord::Migration[8.1]
  def up
    deduplicate_future_buckets!
    remove_index :future_buckets, :user_id if index_exists?(:future_buckets, :user_id)
    add_index :future_buckets, :user_id, unique: true
  end

  def down
    remove_index :future_buckets, :user_id if index_exists?(:future_buckets, :user_id)
    add_index :future_buckets, :user_id
  end

  private

  def deduplicate_future_buckets!
    duplicates = execute(<<~SQL)
      SELECT user_id
      FROM future_buckets
      GROUP BY user_id
      HAVING COUNT(*) > 1
    SQL

    duplicates.each do |row|
      user_id = row['user_id']
      keep_id = select_value(<<~SQL)
        SELECT id
        FROM future_buckets
        WHERE user_id = #{user_id}
        ORDER BY id ASC
        LIMIT 1
      SQL

      execute(<<~SQL)
        UPDATE monthly_buckets
        SET future_bucket_id = #{keep_id}
        WHERE future_bucket_id IN (
          SELECT id
          FROM future_buckets
          WHERE user_id = #{user_id}
            AND id != #{keep_id}
        )
      SQL

      execute(<<~SQL)
        DELETE FROM buckets
        WHERE bucketable_type = 'FutureBucket'
          AND bucketable_id IN (
            SELECT id
            FROM future_buckets
            WHERE user_id = #{user_id}
              AND id != #{keep_id}
          )
      SQL

      execute(<<~SQL)
        DELETE FROM future_buckets
        WHERE user_id = #{user_id}
          AND id != #{keep_id}
      SQL
    end
  end
end
