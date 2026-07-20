# frozen_string_literal: true

require "test_helper"

class TrackerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @monthlylog = create_monthlylog!(@user, name: Date.current.strftime('%B %Y'))
    @tracker = @monthlylog.trackers.create!(name: "Run", schedule: { "days" => (0..6).to_a })
  end

  test "scheduled_on matches selected days within month" do
    today = Date.current

    assert @tracker.scheduled_on?(today)
    assert @tracker.scheduled_on?(today + 1.day) if (today + 1.day).month == today.month
  end

  test "scheduled_on skips unselected days" do
    today = Date.current
    @tracker.update!(schedule: { "days" => [today.wday] })

    assert @tracker.scheduled_on?(today)
    assert_not @tracker.scheduled_on?(today + 1.day)
  end

  test "active_from is monthlylog period start" do
    assert_equal @monthlylog.period_from, @tracker.active_from
  end

  test "scheduled_on false outside monthly period" do
    assert_not @tracker.scheduled_on?(@monthlylog.period_from - 1.day)
  end

  test "destroy removes completions" do
    @tracker.completions.create!(date: Date.current, completed_at: Time.current)

    assert_difference -> { Tracker::Completion.count }, -1 do
      @tracker.destroy!
    end
  end

  test "with_completions preloads completed dates" do
    @tracker.completions.create!(date: Date.current, completed_at: Time.current)
    loaded = @monthlylog.trackers.chronological.with_completions
    tracker = loaded.find { |row| row.id == @tracker.id }

    assert tracker.completed?(Date.current)
    assert_not tracker.completed?(Date.current - 1.day)
  end

  test "current streak counts consecutive scheduled days" do
    day = Date.current
    @tracker.completions.create!(date: day, completed_at: Time.current)
    @tracker.completions.create!(date: day - 1.day, completed_at: Time.current) if day > @monthlylog.period_from
    loaded = @monthlylog.trackers.where(id: @tracker.id).with_completions.first
    statistics = loaded.statistics(as_of: day)

    assert statistics[:streak] >= 1
  end
end
