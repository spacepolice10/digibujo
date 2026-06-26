# frozen_string_literal: true

require "test_helper"

class RecurrencyTrackerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @recurrency = @user.recurrencies.create!(name: "Run", schedule: { "days" => (0..6).to_a })
    @from = Date.current.beginning_of_month
    @to = Date.current.end_of_month
    @recurrency.update_column(:created_at, @from.in_time_zone.beginning_of_day)
  end

  test "includes recurrency overlapping tracker range" do
    @recurrency.update_column(:created_at, (@to + 1.day).in_time_zone.beginning_of_day)

    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @to)

    assert_empty tracker.recurrencies
  end

  test "completed reflects completion for date in range" do
    @recurrency.completions.create!(date: @from, completed_at: Time.current)
    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @to)

    assert tracker.completed?(@recurrency, @from)
    assert_not tracker.completed?(@recurrency, @from + 1.day)
  end

  test "statistics period completed and scheduled for month" do
    @recurrency.completions.create!(date: @from, completed_at: Time.current)
    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @from + 2.days)
    statistics = tracker.statistics(@recurrency)

    assert_equal 1, statistics[:period_completed]
    assert_equal 3, statistics[:period_scheduled]
    assert_equal 1, statistics[:total]
  end

  test "current streak counts consecutive scheduled days" do
    day = Date.current
    @recurrency.completions.create!(date: day, completed_at: Time.current)
    @recurrency.completions.create!(date: day - 1.day, completed_at: Time.current)
    tracker = RecurrencyTracker.new(user: @user, from: day - 7.days, to: day)
    statistics = tracker.statistics(@recurrency, as_of: day)

    assert_equal 2, statistics[:streak]
  end

  test "max scheduled per day reports busiest day in range" do
    @recurrency.update!(schedule: { "days" => [0] })
    second = @user.recurrencies.create!(name: "Read", schedule: { "days" => (0..6).to_a })
    second.update_column(:created_at, @from.in_time_zone.beginning_of_day)
    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @to)

    assert_equal 2, tracker.max_scheduled_per_day
  end
end
