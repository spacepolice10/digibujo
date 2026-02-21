class AddStashedAndPinnedToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :stashed, :boolean, default: false, null: false
    add_column :cards, :pinned, :boolean, default: false, null: false
  end
end
