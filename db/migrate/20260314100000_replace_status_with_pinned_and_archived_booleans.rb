class ReplaceStatusWithPinnedAndArchivedBooleans < ActiveRecord::Migration[8.1]
  def change
    remove_column :bullets, :status, :string, default: "active", null: false
    add_column :bullets, :pinned, :boolean, default: false, null: false
    add_column :bullets, :archived, :boolean, default: false, null: false
    add_index :bullets, [ :user_id, :pinned ]
    add_index :bullets, [ :user_id, :archived ]
  end
end
