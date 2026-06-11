# frozen_string_literal: true

require "test_helper"

class MonthlylogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "current? when period_from is this month" do
    monthlylog = create_monthlylog!(@user, name: "june")

    assert monthlylog.current?
  end

  test "current returns monthlylog for this month" do
    monthlylog = create_monthlylog!(@user, name: "june")

    assert_equal monthlylog, Monthlylog.current(@user)
  end

  test "current returns nil when no spread covers this month" do
    period = Bucket.monthlylog_period
    monthlylog = Monthlylog.create!
    @user.buckets.create!(
      bucketable: monthlylog,
      name: "last month",
      period_from: period[:period_from].prev_month,
      period_to: period[:period_to].prev_month.end_of_month
    )

    assert_nil Monthlylog.current(@user)
  end
end
