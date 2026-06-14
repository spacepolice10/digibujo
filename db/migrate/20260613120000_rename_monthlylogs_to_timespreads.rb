class RenameMonthlylogsToTimespreads < ActiveRecord::Migration[8.1]
  def change
    rename_table :monthlylogs, :timespreads

    change_table :timespreads, bulk: true do |t|
      t.date :period_from
      t.date :period_to
    end

    change_table :buckets, bulk: true do |t|
      t.remove :period_from
      t.remove :period_to
    end
  end
end
