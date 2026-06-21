# frozen_string_literal: true

require "test_helper"

class RecurrencyTrackerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @recurrency = @user.recurrencies.create!(name: "Run", schedule: { "kind" => "daily" })
    @from = Date.current.beginning_of_month
    @to = Date.current.end_of_month
  end

  test "includes recurrency overlapping tracker range" do
    @recurrency.update!(active_to: @from - 1.day)

    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @to)

    assert_empty tracker.recurrencies
  end

  test "completed reflects completion for date in range" do
    @recurrency.completions.create!(date: @from, completed_at: Time.current)
    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @to)

    assert tracker.completed?(@recurrency, @from)
    assert_not tracker.completed?(@recurrency, @from + 1.day)
  end

  test "stats period completed and scheduled for month" do
    @recurrency.completions.create!(date: @from, completed_at: Time.current)
    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @from + 2.days)
    stats = tracker.stats(@recurrency)

    assert_equal 1, stats[:period_completed]
    assert_equal 3, stats[:period_scheduled]
    assert_equal 1, stats[:total]
  end

  test "current streak counts consecutive scheduled days" do
    day = Date.current
    @recurrency.completions.create!(date: day, completed_at: Time.current)
    @recurrency.completions.create!(date: day - 1.day, completed_at: Time.current)
    tracker = RecurrencyTracker.new(user: @user, from: day - 7.days, to: day)
    stats = tracker.stats(@recurrency, as_of: day)

    assert_equal 2, stats[:streak]
  end
end
