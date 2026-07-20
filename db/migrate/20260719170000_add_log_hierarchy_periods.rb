# frozen_string_literal: true

class AddLogHierarchyPeriods < ActiveRecord::Migration[8.1]
  class MigrationFuture < ApplicationRecord
    self.table_name = 'futures'
  end

  class MigrationMonthlylog < ApplicationRecord
    self.table_name = 'monthlylogs'
  end

  class MigrationDaylog < ApplicationRecord
    self.table_name = 'daylogs'
  end

  class MigrationBucket < ApplicationRecord
    self.table_name = 'buckets'
  end

  def up
    unless column_exists?(:futures, :period_from)
      add_column :futures, :period_from, :date
      add_column :futures, :period_to, :date

      MigrationFuture.reset_column_information
      MigrationFuture.find_each do |future|
        from = future.created_at.to_date.beginning_of_month
        future.update_columns(
          period_from: from,
          period_to: (from + 5.months).end_of_month
        )
      end

      change_column_null :futures, :period_from, false
      change_column_null :futures, :period_to, false
      add_index :futures, %i[user_id period_from], unique: true unless index_exists?(:futures, %i[user_id period_from])
    end

    unless column_exists?(:monthlylogs, :future_id)
      add_reference :monthlylogs, :future, foreign_key: { to_table: :futures }

      MigrationMonthlylog.reset_column_information
      MigrationMonthlylog.find_each do |monthlylog|
        future = MigrationFuture
                 .where(user_id: monthlylog.user_id)
                 .where('period_from <= ? AND period_to >= ?', monthlylog.period_from, monthlylog.period_to)
                 .first

        unless future
          from = monthlylog.period_from.beginning_of_month
          future = MigrationFuture.create!(
            user_id: monthlylog.user_id,
            period_from: from,
            period_to: (from + 5.months).end_of_month,
            created_at: Time.current,
            updated_at: Time.current
          )
          unless MigrationBucket.exists?(bucketable_type: 'Future', bucketable_id: future.id)
            MigrationBucket.create!(
              user_id: monthlylog.user_id,
              bucketable_type: 'Future',
              bucketable_id: future.id,
              name: 'Future Log',
              icon: 'calendar',
              colour: 'gold',
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        monthlylog.update_columns(future_id: future.id)
      end

      change_column_null :monthlylogs, :future_id, false
    end

    unless column_exists?(:daylogs, :monthlylog_id)
      add_reference :daylogs, :monthlylog, foreign_key: { to_table: :monthlylogs }, index: false
    end

    MigrationDaylog.reset_column_information
    MigrationMonthlylog.reset_column_information

    # One daylog per monthlylog requires multiple daylogs per user — drop unique first.
    if index_exists?(:daylogs, :user_id, unique: true)
      remove_index :daylogs, :user_id
      add_index :daylogs, :user_id unless index_exists?(:daylogs, :user_id)
    end

    MigrationDaylog.find_each do |daylog|
      next if daylog.monthlylog_id.present?

      month_start = Date.current.beginning_of_month
      monthlylog = MigrationMonthlylog.find_by(user_id: daylog.user_id, period_from: month_start)

      unless monthlylog
        future = MigrationFuture
                 .where(user_id: daylog.user_id)
                 .where('period_from <= ? AND period_to >= ?', month_start, month_start.end_of_month)
                 .first

        unless future
          future = MigrationFuture.create!(
            user_id: daylog.user_id,
            period_from: month_start,
            period_to: (month_start + 5.months).end_of_month,
            created_at: Time.current,
            updated_at: Time.current
          )
          MigrationBucket.create!(
            user_id: daylog.user_id,
            bucketable_type: 'Future',
            bucketable_id: future.id,
            name: 'Future Log',
            icon: 'calendar',
            colour: 'gold',
            created_at: Time.current,
            updated_at: Time.current
          )
        end

        monthlylog = MigrationMonthlylog.create!(
          user_id: daylog.user_id,
          future_id: future.id,
          period_from: month_start,
          period_to: month_start.end_of_month,
          created_at: Time.current,
          updated_at: Time.current
        )
        unless MigrationBucket.exists?(bucketable_type: 'Monthlylog', bucketable_id: monthlylog.id)
          MigrationBucket.create!(
            user_id: daylog.user_id,
            bucketable_type: 'Monthlylog',
            bucketable_id: monthlylog.id,
            name: month_start.strftime('%B %Y'),
            icon: 'calendar',
            created_at: Time.current,
            updated_at: Time.current
          )
        end
      end

      daylog.update_columns(monthlylog_id: monthlylog.id)
    end

    MigrationMonthlylog.find_each do |monthlylog|
      next if MigrationDaylog.exists?(monthlylog_id: monthlylog.id)

      daylog = MigrationDaylog.create!(
        user_id: monthlylog.user_id,
        monthlylog_id: monthlylog.id,
        created_at: Time.current,
        updated_at: Time.current
      )
      MigrationBucket.create!(
        user_id: monthlylog.user_id,
        bucketable_type: 'Daylog',
        bucketable_id: daylog.id,
        name: 'Daylog',
        icon: 'calendar',
        created_at: Time.current,
        updated_at: Time.current
      )
    end

    change_column_null :daylogs, :monthlylog_id, false
    add_index :daylogs, :monthlylog_id, unique: true unless index_exists?(:daylogs, :monthlylog_id)
  end

  def down
    remove_index :daylogs, :monthlylog_id if index_exists?(:daylogs, :monthlylog_id)
    remove_index :daylogs, :user_id if index_exists?(:daylogs, :user_id)
    remove_reference :daylogs, :monthlylog, foreign_key: true if column_exists?(:daylogs, :monthlylog_id)
    add_index :daylogs, :user_id, unique: true unless index_exists?(:daylogs, :user_id)

    remove_reference :monthlylogs, :future, foreign_key: true if column_exists?(:monthlylogs, :future_id)

    if column_exists?(:futures, :period_from)
      remove_index :futures, %i[user_id period_from] if index_exists?(:futures, %i[user_id period_from])
      remove_column :futures, :period_to
      remove_column :futures, :period_from
    end
  end
end
