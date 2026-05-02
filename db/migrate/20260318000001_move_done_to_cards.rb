class MoveDoneToCards < ActiveRecord::Migration[8.1]
  def up
    add_column :bullets, :done, :boolean, default: false, null: false
    add_column :bullets, :done_at, :datetime
    add_index :bullets, [ :user_id, :done ]

    execute <<~SQL
      UPDATE bullets
      SET done    = (SELECT tasks.done    FROM tasks WHERE tasks.id = bullets.cardable_id),
          done_at = (SELECT tasks.done_at FROM tasks WHERE tasks.id = bullets.cardable_id)
      WHERE bullets.cardable_type = 'Task'
    SQL

    execute <<~SQL
      UPDATE bullets
      SET done    = (SELECT events.done    FROM events WHERE events.id = bullets.cardable_id),
          done_at = (SELECT events.done_at FROM events WHERE events.id = bullets.cardable_id)
      WHERE bullets.cardable_type = 'Event'
    SQL

    remove_column :tasks, :done
    remove_column :tasks, :done_at
    remove_column :events, :done
    remove_column :events, :done_at
  end

  def down
    add_column :tasks, :done, :boolean, default: false, null: false
    add_column :tasks, :done_at, :datetime
    add_column :events, :done, :boolean, default: false, null: false
    add_column :events, :done_at, :datetime

    execute <<~SQL
      UPDATE tasks
      SET done    = (SELECT bullets.done    FROM bullets WHERE bullets.cardable_type = 'Task' AND bullets.cardable_id = tasks.id),
          done_at = (SELECT bullets.done_at FROM bullets WHERE bullets.cardable_type = 'Task' AND bullets.cardable_id = tasks.id)
    SQL

    execute <<~SQL
      UPDATE events
      SET done    = (SELECT bullets.done    FROM bullets WHERE bullets.cardable_type = 'Event' AND bullets.cardable_id = events.id),
          done_at = (SELECT bullets.done_at FROM bullets WHERE bullets.cardable_type = 'Event' AND bullets.cardable_id = events.id)
    SQL

    remove_index :bullets, [ :user_id, :done ]
    remove_column :bullets, :done
    remove_column :bullets, :done_at
  end
end
