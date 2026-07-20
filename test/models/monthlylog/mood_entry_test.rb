# frozen_string_literal: true

require 'test_helper'

class Monthlylog::MoodEntryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @monthlylog = create_monthlylog!(@user, name: Date.current.strftime('%B %Y'))
    @monthlylog.update!(mood_tracker_enabled: true)
  end

  test 'creates mood entry for a day in the month' do
    entry = @monthlylog.mood_entries.create!(date: Date.current, mood: :inspired)

    assert_equal 'inspired', entry.mood
    assert_equal '✨', entry.marker
  end

  test 'rejects date outside monthly period' do
    entry = @monthlylog.mood_entries.new(date: @monthlylog.period_from - 1.day, mood: :positive)

    assert_not entry.valid?
    assert_includes entry.errors[:date], 'must be within the monthly spread'
  end

  test 'enforces one entry per date' do
    @monthlylog.mood_entries.create!(date: Date.current, mood: :positive)
    duplicate = @monthlylog.mood_entries.new(date: Date.current, mood: :negative)

    assert_not duplicate.valid?
  end
end
