# frozen_string_literal: true

class AddCalendarDateIdToTrackerStatuses < ActiveRecord::Migration[8.1]
  def change
    add_reference :tracker_statuses, :calendar_date, foreign_key: true, index: false

    reversible do |dir|
      dir.up do
        change_column_null :tracker_statuses, :date, true
        backfill_calendar_dates
        link_statuses
        change_column_null :tracker_statuses, :calendar_date_id, false
        remove_index :tracker_statuses, column: %i[tracker_id date]
        add_index :tracker_statuses, %i[tracker_id calendar_date_id], unique: true,
                  name: 'index_tracker_statuses_on_tracker_and_calendar_date'
      end

      dir.down do
        remove_index :tracker_statuses, name: 'index_tracker_statuses_on_tracker_and_calendar_date'
        add_index :tracker_statuses, %i[tracker_id date], unique: true
        change_column_null :tracker_statuses, :date, false
      end
    end
  end

  private

  def backfill_calendar_dates
    execute <<~SQL.squish
      INSERT OR IGNORE INTO calendar_dates (user_id, date, created_at, updated_at)
      SELECT monthlylogs.user_id, tracker_statuses.date, datetime('now'), datetime('now')
      FROM tracker_statuses
      JOIN trackers ON trackers.id = tracker_statuses.tracker_id
      JOIN monthlylogs ON monthlylogs.id = trackers.monthlylog_id
    SQL
  end

  def link_statuses
    execute <<~SQL.squish
      UPDATE tracker_statuses
      SET calendar_date_id = (
        SELECT calendar_dates.id
        FROM calendar_dates
        JOIN monthlylogs ON monthlylogs.user_id = calendar_dates.user_id
        JOIN trackers ON trackers.monthlylog_id = monthlylogs.id
        WHERE trackers.id = tracker_statuses.tracker_id
        AND calendar_dates.date = tracker_statuses.date
      )
    SQL
  end
end
