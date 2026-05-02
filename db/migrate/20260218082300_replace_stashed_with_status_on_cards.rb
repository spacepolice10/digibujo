class ReplaceStashedWithStatusOnCards < ActiveRecord::Migration[8.1]
  def up
    add_column :bullets, :status, :string, default: "active", null: false

    execute <<~SQL
      UPDATE bullets SET status = 'stashed' WHERE stashed = TRUE
    SQL

    remove_column :bullets, :stashed
    add_index :bullets, [ :user_id, :status ]
  end

  def down
    add_column :bullets, :stashed, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE bullets SET stashed = TRUE WHERE status = 'stashed'
    SQL

    remove_index :bullets, [ :user_id, :status ]
    remove_column :bullets, :status
  end
end
