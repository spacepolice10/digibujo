class ReplaceStashedWithStatusOnCards < ActiveRecord::Migration[8.1]
  def up
    add_column :cards, :status, :string, default: "active", null: false

    execute <<~SQL
      UPDATE cards SET status = 'stashed' WHERE stashed = TRUE
    SQL

    remove_column :cards, :stashed
    add_index :cards, [ :user_id, :status ]
  end

  def down
    add_column :cards, :stashed, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE cards SET stashed = TRUE WHERE status = 'stashed'
    SQL

    remove_index :cards, [ :user_id, :status ]
    remove_column :cards, :status
  end
end
