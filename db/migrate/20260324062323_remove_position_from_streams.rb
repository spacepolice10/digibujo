class RemovePositionFromStreams < ActiveRecord::Migration[8.1]
  def change
    remove_column :streams, :position, :integer
  end
end
