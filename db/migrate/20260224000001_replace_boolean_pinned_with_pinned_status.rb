class ReplaceBooleanPinnedWithPinnedStatus < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE bullets SET status = 'pinned' WHERE status = 'stashed'"
    remove_column :bullets, :pinned
  end

  def down
    add_column :bullets, :pinned, :boolean, default: false, null: false
    execute "UPDATE bullets SET status = 'stashed' WHERE status = 'pinned'"
  end
end
