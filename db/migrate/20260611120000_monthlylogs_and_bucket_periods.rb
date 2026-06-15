# frozen_string_literal: true

class MonthlylogsAndBucketPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :monthlylogs, &:timestamps

    change_table :buckets, bulk: true do |t|
      t.date :period_from
      t.date :period_to
    end
  end
end
