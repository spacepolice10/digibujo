class ReplaceBooleanPinnedWithPinnedStatus < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE cards SET status = 'pinned' WHERE status = 'stashed'"
    remove_column :cards, :pinned
  end

  def down
    add_column :cards, :pinned, :boolean, default: false, null: false
    execute "UPDATE cards SET status = 'stashed' WHERE status = 'pinned'"
  end
end
