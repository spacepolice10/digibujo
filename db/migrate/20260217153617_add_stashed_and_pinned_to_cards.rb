class AddStashedAndPinnedToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :stashed, :boolean, default: false, null: false
    add_column :bullets, :pinned, :boolean, default: false, null: false
  end
end
