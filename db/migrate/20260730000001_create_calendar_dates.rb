# frozen_string_literal: true

class CreateCalendarDates < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_dates do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.timestamps
    end

    add_index :calendar_dates, %i[user_id date], unique: true

    rename_table :daylog_mood_entities, :calendar_date_mood_entities
    rename_table :daylog_pictures, :calendar_date_pictures

    reversible do |dir|
      dir.up do
        change_column_null :calendar_date_mood_entities, :date, true
        change_column_null :calendar_date_pictures, :date, true
        change_column_null :calendar_date_mood_entities, :daylog_id, true
        change_column_null :calendar_date_pictures, :daylog_id, true
        backfill_calendar_dates
        add_reference :calendar_date_mood_entities, :calendar_date, foreign_key: true, index: false
        add_reference :calendar_date_pictures, :calendar_date, foreign_key: true, index: false
        link_existing_records
        change_column_null :calendar_date_mood_entities, :calendar_date_id, false
        change_column_null :calendar_date_pictures, :calendar_date_id, false
        add_index :calendar_date_mood_entities, :calendar_date_id, unique: true
        add_index :calendar_date_pictures, :calendar_date_id, unique: true
      end

      dir.down do
        remove_index :calendar_date_mood_entities, :calendar_date_id
        remove_index :calendar_date_pictures, :calendar_date_id
        remove_reference :calendar_date_mood_entities, :calendar_date
        remove_reference :calendar_date_pictures, :calendar_date
        change_column_null :calendar_date_mood_entities, :daylog_id, false
        change_column_null :calendar_date_pictures, :daylog_id, false
        change_column_null :calendar_date_mood_entities, :date, false
        change_column_null :calendar_date_pictures, :date, false
      end
    end
  end

  private

  def backfill_calendar_dates
    execute <<~SQL.squish
      INSERT OR IGNORE INTO calendar_dates (user_id, date, created_at, updated_at)
      SELECT daylogs.user_id, dates.date, datetime('now'), datetime('now')
      FROM (
        SELECT daylog_id, date FROM calendar_date_mood_entities
        UNION
        SELECT daylog_id, date FROM calendar_date_pictures
      ) dates
      JOIN daylogs ON daylogs.id = dates.daylog_id
    SQL
  end

  def link_existing_records
    execute <<~SQL.squish
      UPDATE calendar_date_mood_entities
      SET calendar_date_id = (
        SELECT calendar_dates.id
        FROM calendar_dates
        JOIN daylogs ON daylogs.user_id = calendar_dates.user_id
        WHERE daylogs.id = calendar_date_mood_entities.daylog_id
        AND calendar_dates.date = calendar_date_mood_entities.date
      )
    SQL

    execute <<~SQL.squish
      UPDATE calendar_date_pictures
      SET calendar_date_id = (
        SELECT calendar_dates.id
        FROM calendar_dates
        JOIN daylogs ON daylogs.user_id = calendar_dates.user_id
        WHERE daylogs.id = calendar_date_pictures.daylog_id
        AND calendar_dates.date = calendar_date_pictures.date
      )
    SQL
  end
end
