# frozen_string_literal: true

require "test_helper"

class PeriodableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @monthlylog = Monthlylog.create!
    @bucket = @user.buckets.build(
      bucketable: @monthlylog,
      name: "june",
      period_from: Date.new(2026, 6, 1),
      period_to: Date.new(2026, 6, 30)
    )
  end

  test "monthlylog_period returns current month boundaries" do
    period = Bucket.monthlylog_period

    assert_equal Date.current.beginning_of_month, period[:period_from]
    assert_equal Date.current.end_of_month, period[:period_to]
  end

  test "period_days returns inclusive range" do
    @bucket.save!

    assert_equal Date.new(2026, 6, 1)..Date.new(2026, 6, 30), @bucket.period_days
  end

  test "period_ranges_correct rejects to before from" do
    @bucket.period_from = Date.new(2026, 6, 15)
    @bucket.period_to = Date.new(2026, 5, 15)

    assert_not @bucket.valid?
    assert_includes @bucket.errors[:period_to], "must be on or after From"
  end

  test "period_ranges_correct requires both or neither" do
    @bucket.period_from = Date.new(2026, 6, 1)
    @bucket.period_to = nil

    assert_not @bucket.valid?
    assert_includes @bucket.errors[:base], "From and To must both be set or both be blank"
  end
end
