class MoveDoneToCards < ActiveRecord::Migration[8.1]
  def up
    add_column :cards, :done, :boolean, default: false, null: false
    add_column :cards, :done_at, :datetime
    add_index :cards, [ :user_id, :done ]

    execute <<~SQL
      UPDATE cards
      SET done    = (SELECT tasks.done    FROM tasks WHERE tasks.id = cards.cardable_id),
          done_at = (SELECT tasks.done_at FROM tasks WHERE tasks.id = cards.cardable_id)
      WHERE cards.cardable_type = 'Task'
    SQL

    execute <<~SQL
      UPDATE cards
      SET done    = (SELECT events.done    FROM events WHERE events.id = cards.cardable_id),
          done_at = (SELECT events.done_at FROM events WHERE events.id = cards.cardable_id)
      WHERE cards.cardable_type = 'Event'
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
      SET done    = (SELECT cards.done    FROM cards WHERE cards.cardable_type = 'Task' AND cards.cardable_id = tasks.id),
          done_at = (SELECT cards.done_at FROM cards WHERE cards.cardable_type = 'Task' AND cards.cardable_id = tasks.id)
    SQL

    execute <<~SQL
      UPDATE events
      SET done    = (SELECT cards.done    FROM cards WHERE cards.cardable_type = 'Event' AND cards.cardable_id = events.id),
          done_at = (SELECT cards.done_at FROM cards WHERE cards.cardable_type = 'Event' AND cards.cardable_id = events.id)
    SQL

    remove_index :cards, [ :user_id, :done ]
    remove_column :cards, :done
    remove_column :cards, :done_at
  end
end
