class MoveCompletionFromBulletsToTasks < ActiveRecord::Migration[8.1]
  def up
    add_column :tasks, :done, :boolean, default: false, null: false
    add_column :tasks, :done_at, :datetime

    execute <<~SQL.squish
      UPDATE tasks
      SET
        done = bullets.done,
        done_at = bullets.done_at
      FROM bullets
      WHERE bullets.bulletable_type = 'Task'
        AND bullets.bulletable_id = tasks.id
    SQL

    remove_index :bullets, [ :user_id, :done ]
    remove_column :bullets, :done, :boolean, default: false, null: false
    remove_column :bullets, :done_at, :datetime
  end

  def down
    add_column :bullets, :done, :boolean, default: false, null: false
    add_column :bullets, :done_at, :datetime
    add_index :bullets, [ :user_id, :done ]

    execute <<~SQL.squish
      UPDATE bullets
      SET
        done = tasks.done,
        done_at = tasks.done_at
      FROM tasks
      WHERE bullets.bulletable_type = 'Task'
        AND bullets.bulletable_id = tasks.id
    SQL

    remove_column :tasks, :done, :boolean, default: false, null: false
    remove_column :tasks, :done_at, :datetime
  end
end
