class CleanUpCardSchema < ActiveRecord::Migration[8.1]
  def change
    remove_timestamps :tasks
    remove_timestamps :notes
    add_column :bullets, :date, :date
  end
end
