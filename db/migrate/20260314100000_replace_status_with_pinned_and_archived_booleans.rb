class ReplaceStatusWithPinnedAndArchivedBooleans < ActiveRecord::Migration[8.1]
  def change
    remove_column :cards, :status, :string, default: "active", null: false
    add_column :cards, :pinned, :boolean, default: false, null: false
    add_column :cards, :archived, :boolean, default: false, null: false
    add_index :cards, [ :user_id, :pinned ]
    add_index :cards, [ :user_id, :archived ]
  end
end
