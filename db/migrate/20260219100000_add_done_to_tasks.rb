class AddDoneToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :done, :boolean, default: false, null: false
    add_column :tasks, :done_at, :datetime
  end
end
