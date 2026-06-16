# frozen_string_literal: true

class BackfillUserSettings < ActiveRecord::Migration[8.1]
  def up
    # Users created before user_settings existed have no settings row.
    # Backfill them with the column defaults.
    execute <<~SQL.squish
      INSERT INTO user_settings (user_id, logs_open, projects_open, collections_open, spreads_open, created_at, updated_at)
      SELECT id, 1, 1, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users
      WHERE id NOT IN (SELECT user_id FROM user_settings)
    SQL
  end

  def down
    # Data migration; no rollback needed.
  end
end
