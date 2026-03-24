class ChangeCardDateColumnsToDatetime < ActiveRecord::Migration[8.1]
  def up
    change_column :cards, :date, :datetime
    change_column :cards, :ends_date, :datetime
  end

  def down
    change_column :cards, :date, :date
    change_column :cards, :ends_date, :date
  end
end
