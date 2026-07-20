# frozen_string_literal: true

class NestTrackersAndAddMonthlyMood < ActiveRecord::Migration[8.1]
  def up
    add_reference :trackers, :monthlylog, foreign_key: true

    # Attach existing trackers to a monthlylog for their creation month, or drop them.
    say_with_time 'Backfill tracker monthlylog_id' do
      execute <<~SQL.squish
        UPDATE trackers
        SET monthlylog_id = (
          SELECT monthlylogs.id FROM monthlylogs
          WHERE monthlylogs.user_id = trackers.user_id
            AND monthlylogs.period_from = date(trackers.created_at, 'start of month')
          LIMIT 1
        )
      SQL
      execute 'DELETE FROM tracker_completions WHERE tracker_id IN (SELECT id FROM trackers WHERE monthlylog_id IS NULL)'
      execute 'DELETE FROM trackers WHERE monthlylog_id IS NULL'
    end

    change_column_null :trackers, :monthlylog_id, false
    remove_column :trackers, :stopped_on, :date
    remove_column :trackers, :user_id, :integer

    add_column :monthlylogs, :mood_tracker_enabled, :boolean, default: false, null: false

    create_table :monthlylog_mood_entries do |t|
      t.references :monthlylog, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :mood, null: false
      t.timestamps
    end
    add_index :monthlylog_mood_entries, %i[monthlylog_id date], unique: true

    remove_column :notes, :mood, :integer
    remove_column :user_settings, :trackers_expanded, :boolean, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
