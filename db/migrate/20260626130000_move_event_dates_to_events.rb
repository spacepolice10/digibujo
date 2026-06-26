# frozen_string_literal: true

class MoveEventDatesToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :starts_date, :date
    add_column :events, :ends_date, :date

    execute <<~SQL.squish
      UPDATE events
      SET ends_date = (
        SELECT bullets.ends_date
        FROM bullets
        WHERE bullets.bulletable_type = 'Event'
          AND bullets.bulletable_id = events.id
          AND bullets.ends_date IS NOT NULL
      )
    SQL

    remove_column :bullets, :ends_date
  end

  def down
    add_column :bullets, :ends_date, :date

    execute <<~SQL.squish
      UPDATE bullets
      SET ends_date = (
        SELECT events.ends_date
        FROM events
        WHERE bullets.bulletable_type = 'Event'
          AND bullets.bulletable_id = events.id
      )
      WHERE bulletable_type = 'Event'
    SQL

    remove_column :events, :starts_date
    remove_column :events, :ends_date
  end
end
