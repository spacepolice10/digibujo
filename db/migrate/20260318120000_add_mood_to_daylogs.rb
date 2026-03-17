class AddMoodToDaylogs < ActiveRecord::Migration[8.1]
  def change
    add_column :daylogs, :mood, :integer
  end
end
