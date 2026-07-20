# frozen_string_literal: true

require 'test_helper'

class Monthlylogs::MoodEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @monthlylog = create_monthlylog!(@user, name: Date.current.strftime('%B %Y'))
    @monthlylog.update!(mood_tracker_enabled: true)
    @date = Date.current
  end

  test 'create mood entry' do
    assert_difference -> { @monthlylog.mood_entries.count }, 1 do
      post monthlylog_mood_entry_path(@monthlylog), params: { date: @date.iso8601, mood: 'inspired' }
    end

    assert_redirected_to monthlylog_path(@monthlylog)
    assert_equal 'inspired', @monthlylog.mood_entries.find_by!(date: @date).mood
  end

  test 'destroy mood entry' do
    @monthlylog.mood_entries.create!(date: @date, mood: :positive)

    assert_difference -> { @monthlylog.mood_entries.count }, -1 do
      delete monthlylog_mood_entry_path(@monthlylog, date: @date.iso8601)
    end

    assert_redirected_to monthlylog_path(@monthlylog)
  end

  test 'create is not found when mood tracker disabled' do
    @monthlylog.update!(mood_tracker_enabled: false)

    assert_no_difference -> { Monthlylog::MoodEntry.count } do
      post monthlylog_mood_entry_path(@monthlylog), params: { date: @date.iso8601, mood: 'positive' }
    end

    assert_response :not_found
  end
end
