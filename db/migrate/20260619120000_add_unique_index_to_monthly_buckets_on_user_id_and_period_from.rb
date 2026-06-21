# frozen_string_literal: true

class AddUniqueIndexToMonthlyBucketsOnUserIdAndPeriodFrom < ActiveRecord::Migration[8.1]
  def change
    add_index :monthly_buckets, %i[user_id period_from], unique: true
  end
end
