class AddMoodToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :mood, :integer
  end
end
