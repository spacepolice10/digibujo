class ChangeCardDateColumnsToDatetime < ActiveRecord::Migration[8.1]
  def up
    change_column :bullets, :date, :datetime
    change_column :bullets, :ends_date, :datetime
  end

  def down
    change_column :bullets, :date, :date
    change_column :bullets, :ends_date, :date
  end
end
