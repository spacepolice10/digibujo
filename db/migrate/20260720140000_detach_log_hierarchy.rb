# frozen_string_literal: true

class DetachLogHierarchy < ActiveRecord::Migration[8.1]
  class MigrationDaylog < ApplicationRecord
    self.table_name = 'daylogs'
  end

  class MigrationMonthlylog < ApplicationRecord
    self.table_name = 'monthlylogs'
  end

  class MigrationBucket < ApplicationRecord
    self.table_name = 'buckets'
  end

  class MigrationBullet < ApplicationRecord
    self.table_name = 'bullets'
  end

  def up
    return if already_detached?

    merge_daylogs_to_one_per_user!

    if column_exists?(:daylogs, :monthlylog_id)
      remove_foreign_key :daylogs, :monthlylogs if foreign_key_exists?(:daylogs, :monthlylogs)
      remove_index :daylogs, :monthlylog_id if index_exists?(:daylogs, :monthlylog_id)
      remove_column :daylogs, :monthlylog_id
    end

    if index_exists?(:daylogs, :user_id)
      remove_index :daylogs, :user_id
    end
    add_index :daylogs, :user_id, unique: true unless index_exists?(:daylogs, :user_id, unique: true)

    if column_exists?(:monthlylogs, :future_id)
      remove_foreign_key :monthlylogs, :futures if foreign_key_exists?(:monthlylogs, :futures)
      remove_index :monthlylogs, :future_id if index_exists?(:monthlylogs, :future_id)
      remove_column :monthlylogs, :future_id
    end
  end

  def down
    add_reference :monthlylogs, :future, foreign_key: { to_table: :futures } unless column_exists?(:monthlylogs, :future_id)

    MigrationMonthlylog.reset_column_information
    MigrationMonthlylog.find_each do |monthlylog|
      future_id = connection.select_value(<<~SQL.squish)
        SELECT futures.id FROM futures
        WHERE futures.user_id = #{monthlylog.user_id.to_i}
        AND futures.period_from <= date('#{monthlylog.period_from}')
        AND futures.period_to >= date('#{monthlylog.period_to}')
        LIMIT 1
      SQL
      next unless future_id

      monthlylog.update_columns(future_id: future_id)
    end

    change_column_null :monthlylogs, :future_id, false

    add_reference :daylogs, :monthlylog, foreign_key: { to_table: :monthlylogs }, index: false unless column_exists?(:daylogs, :monthlylog_id)

    MigrationDaylog.reset_column_information
    MigrationDaylog.find_each do |daylog|
      month_start = Date.current.beginning_of_month
      monthlylog = MigrationMonthlylog.find_by(user_id: daylog.user_id, period_from: month_start)
      next unless monthlylog

      daylog.update_columns(monthlylog_id: monthlylog.id)
    end

    change_column_null :daylogs, :monthlylog_id, false
    remove_index :daylogs, :user_id if index_exists?(:daylogs, :user_id)
    add_index :daylogs, :user_id unless index_exists?(:daylogs, :user_id)
    add_index :daylogs, :monthlylog_id, unique: true unless index_exists?(:daylogs, :monthlylog_id)
  end

  private

  def already_detached?
    !column_exists?(:daylogs, :monthlylog_id) && !column_exists?(:monthlylogs, :future_id)
  end

  def merge_daylogs_to_one_per_user!
    return unless column_exists?(:daylogs, :monthlylog_id)

    current_month = Date.current.beginning_of_month.to_s

    user_ids = MigrationDaylog.group(:user_id).having('COUNT(*) > 1').pluck(:user_id)
    user_ids.each do |user_id|
      daylogs = MigrationDaylog.where(user_id: user_id).order(:id).to_a
      next if daylogs.size <= 1

      keeper = pick_keeper(daylogs, current_month)
      keeper_bucket = bucket_for(keeper) || ensure_bucket_for!(keeper)

      daylogs.each do |daylog|
        next if daylog.id == keeper.id

        bucket = bucket_for(daylog)
        if bucket
          MigrationBullet.where(bucket_id: bucket.id).update_all(bucket_id: keeper_bucket.id)
          # Delete bucket row without AR callbacks (avoids app-model dependents).
          execute("DELETE FROM buckets WHERE id = #{bucket.id.to_i}")
        end
        execute("DELETE FROM daylogs WHERE id = #{daylog.id.to_i}")
      end
    end

    leftovers = MigrationDaylog.group(:user_id).having('COUNT(*) > 1').count
    return if leftovers.empty?

    raise "Still multiple daylogs per user after merge: #{leftovers.inspect}"
  end

  def pick_keeper(daylogs, current_month)
    with_current_month = daylogs.find do |daylog|
      monthlylog = MigrationMonthlylog.find_by(id: daylog.monthlylog_id)
      monthlylog&.period_from&.to_s == current_month
    end
    return with_current_month if with_current_month && bucket_for(with_current_month)

    with_bucket = daylogs.find { |daylog| bucket_for(daylog) }
    with_bucket || daylogs.first
  end

  def bucket_for(daylog)
    MigrationBucket.find_by(bucketable_type: 'Daylog', bucketable_id: daylog.id)
  end

  def ensure_bucket_for!(daylog)
    MigrationBucket.create!(
      user_id: daylog.user_id,
      bucketable_type: 'Daylog',
      bucketable_id: daylog.id,
      name: 'Daylog',
      icon: 'calendar',
      created_at: Time.current,
      updated_at: Time.current
    )
  end
end
