class AddDoneToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :done, :boolean, default: false, null: false
    add_column :events, :done_at, :datetime
  end
end
