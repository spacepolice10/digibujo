# frozen_string_literal: true

require 'test_helper'

class Daylogs::MoodEntitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
    @date = Date.current
  end

  test 'create mood entity' do
    assert_difference -> { @user.daylog.mood_entities.count }, 1 do
      post daylog_mood_entity_path, params: { date: @date.iso8601, mood: 'inspired' }
    end

    assert_redirected_to daylog_path(date: @date.iso8601)
    assert_equal 'inspired', @user.daylog.mood_entities.find_by!(date: @date).mood
  end

  test 'destroy mood entity' do
    @user.daylog.mood_entities.create!(date: @date, mood: :positive)

    assert_difference -> { @user.daylog.mood_entities.count }, -1 do
      delete daylog_mood_entity_path, params: { date: @date.iso8601 }
    end

    assert_redirected_to daylog_path(date: @date.iso8601)
  end

  test 'create redirects back to monthlylog when referred from there' do
    monthlylog = create_monthlylog!(@user, name: Date.current.strftime('%B %Y'))

    post daylog_mood_entity_path,
         params: { date: @date.iso8601, mood: 'positive' },
         headers: { 'HTTP_REFERER' => monthlylog_url(monthlylog) }

    assert_redirected_to monthlylog_path(monthlylog)
  end
end
