# frozen_string_literal: true

require "test_helper"

class TrackerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @tracker = @user.trackers.create!(name: "Run", schedule: { "days" => (0..6).to_a })
  end

  test "scheduled_on matches selected days" do
    today = Date.current

    assert @tracker.scheduled_on?(today)
    assert @tracker.scheduled_on?(today + 1.day)
  end

  test "scheduled_on skips unselected days" do
    today = Date.current
    @tracker.update!(schedule: { "days" => [today.wday] })

    assert @tracker.scheduled_on?(today)
    assert_not @tracker.scheduled_on?(today + 1.day)
  end

  test "active_from is creation date" do
    assert_equal @tracker.created_at.to_date, @tracker.active_from
  end

  test "scheduled_on false before creation date" do
    @tracker.update_column(:created_at, 1.day.from_now.in_time_zone.beginning_of_day)

    assert_not @tracker.scheduled_on?(Date.current)
  end

  test "scheduled_on false after stopped_on" do
    @tracker.stop!(on: Date.current - 1.day)

    assert @tracker.stopped?
    assert_not @tracker.scheduled_on?(Date.current)
  end

  test "stop sets stopped_on" do
    @tracker.stop!(on: Date.current)

    assert_equal Date.current, @tracker.stopped_on
    assert @tracker.stopped?
    assert_not @tracker.open?
  end

  test "destroy removes completions" do
    @tracker.completions.create!(date: Date.current, completed_at: Time.current)

    assert_difference -> { Tracker::Completion.count }, -1 do
      @tracker.destroy!
    end
  end

  test "with_completions preloads completed dates" do
    @tracker.completions.create!(date: Date.current, completed_at: Time.current)
    loaded = @user.trackers.open.chronological.with_completions
    tracker = loaded.find { |row| row.id == @tracker.id }

    assert tracker.completed?(Date.current)
    assert_not tracker.completed?(Date.current - 1.day)
  end

  test "statistics period covers active lifetime" do
    @tracker.update_column(:created_at, (Date.current - 2.days).in_time_zone.beginning_of_day)
    @tracker.completions.create!(date: Date.current - 2.days, completed_at: Time.current)
    loaded = @user.trackers.where(id: @tracker.id).with_completions.first
    statistics = loaded.statistics(as_of: Date.current)

    assert_equal 1, statistics[:period_completed]
    assert_equal 3, statistics[:period_scheduled]
    assert_equal 1, statistics[:total]
  end

  test "current streak counts consecutive scheduled days" do
    day = Date.current
    @tracker.completions.create!(date: day, completed_at: Time.current)
    @tracker.completions.create!(date: day - 1.day, completed_at: Time.current)
    loaded = @user.trackers.where(id: @tracker.id).with_completions.first
    statistics = loaded.statistics(as_of: day)

    assert_equal 2, statistics[:streak]
  end

  test "open scope excludes stopped trackers" do
    @tracker.stop!

    assert_not_includes @user.trackers.open, @tracker
  end
end
