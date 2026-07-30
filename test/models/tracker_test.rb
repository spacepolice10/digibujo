# frozen_string_literal: true

require "test_helper"

class TrackerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @tracker = @user.trackers.create!(name: "Run", schedule: { "days" => (0..6).to_a }, start_date: Date.current)
    @calendar_date = @user.calendar_dates.create!(date: Date.current)
  end

  test "scheduled_on matches selected days" do
    today = Date.current

    assert @tracker.scheduled_on?(today)
    assert_not @tracker.scheduled_on?(today + 1.day)
  end

  test "scheduled_on skips unselected days" do
    today = Date.current
    @tracker.update!(schedule: { "days" => [today.wday] })

    assert @tracker.scheduled_on?(today)
    assert_not @tracker.scheduled_on?(today + 1.day)
  end

  test "active_from is start_date" do
    assert_equal @tracker.start_date, @tracker.active_from
  end

  test "scheduled_on false before start_date" do
    assert_not @tracker.scheduled_on?(@tracker.start_date - 1.day)
  end

  test "destroy removes statuses" do
    @tracker.statuses.create!(calendar_date: @calendar_date, completed_at: Time.current)

    assert_difference -> { Tracker::Status.count }, -1 do
      @tracker.destroy!
    end
  end

  test "with_completions preloads completed dates" do
    @tracker.statuses.create!(calendar_date: @calendar_date, completed_at: Time.current)
    loaded = @user.trackers.chronological.with_completions
    tracker = loaded.find { |row| row.id == @tracker.id }

    assert tracker.completed?(Date.current)
    assert_not tracker.completed?(Date.current - 1.day)
  end

  test "current streak counts consecutive scheduled days" do
    day = Date.current
    cal_today = @calendar_date
    cal_yesterday = @user.calendar_dates.create!(date: day - 1.day)
    @tracker.statuses.create!(calendar_date: cal_today, completed_at: Time.current)
    @tracker.statuses.create!(calendar_date: cal_yesterday, completed_at: Time.current)
    loaded = @user.trackers.where(id: @tracker.id).with_completions.first
    statistics = loaded.statistics(as_of: day)

    assert statistics[:streak] >= 1
  end
end
