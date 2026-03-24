class RemoveDefaultStreams < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM streams WHERE \"default\" = 1"
    remove_column :streams, :default
  end

  def down
    add_column :streams, :default, :boolean, default: false, null: false
  end
end
