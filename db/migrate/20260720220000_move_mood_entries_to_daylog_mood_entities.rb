# frozen_string_literal: true

class MoveMoodEntriesToDaylogMoodEntities < ActiveRecord::Migration[8.1]
  def up
    create_table :daylog_mood_entities do |t|
      t.references :daylog, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :mood, null: false
      t.timestamps
    end
    add_index :daylog_mood_entities, %i[daylog_id date], unique: true

    say_with_time 'Backfill daylog mood entities from monthlylog mood entries' do
      execute <<~SQL.squish
        INSERT OR IGNORE INTO daylog_mood_entities (daylog_id, date, mood, created_at, updated_at)
        SELECT daylogs.id, monthlylog_mood_entries.date, monthlylog_mood_entries.mood,
               monthlylog_mood_entries.created_at, monthlylog_mood_entries.updated_at
        FROM monthlylog_mood_entries
        INNER JOIN monthlylogs ON monthlylogs.id = monthlylog_mood_entries.monthlylog_id
        INNER JOIN daylogs ON daylogs.user_id = monthlylogs.user_id
      SQL
    end

    drop_table :monthlylog_mood_entries
    remove_column :monthlylogs, :mood_tracker_enabled, :boolean
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
