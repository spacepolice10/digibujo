class CleanUpCardSchema < ActiveRecord::Migration[8.1]
  def change
    remove_timestamps :tasks
    remove_timestamps :notes
    add_column :cards, :date, :date
  end
end
