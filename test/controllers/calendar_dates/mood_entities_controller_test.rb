# frozen_string_literal: true

require 'test_helper'

module CalendarDates
  class MoodEntitiesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      ensure_daylog!(@user)
      @date = Date.current
      @mood_dom_id = "mood_entity_#{@date.iso8601}"
      @calendar_date = @user.calendar_dates.create!(date: @date)
    end

    test 'create mood entity updates picker via turbo stream' do
      assert_difference -> { CalendarDate::MoodEntity.count }, 1 do
        post calendar_date_mood_entity_path,
             params: { date: @date.iso8601, mood: 'inspired' },
             as: :turbo_stream
      end

      assert_response :success
      assert_equal 'inspired', @calendar_date.reload.mood_entity.mood
      assert_select "turbo-stream[action=replace][target=#{@mood_dom_id}]", count: 1
    end

    test 'create mood entity redirects html requests back to daylog' do
      assert_difference -> { CalendarDate::MoodEntity.count }, 1 do
        post calendar_date_mood_entity_path, params: { date: @date.iso8601, mood: 'inspired' }
      end

      assert_redirected_to daylog_path(date: @date.iso8601)
    end

    test 'create mood entity redirects back to monthlylog when posted from there' do
      monthlylog = create_monthlylog!(@user, name: @date.strftime('%B %Y'))

      assert_difference -> { CalendarDate::MoodEntity.count }, 1 do
        post calendar_date_mood_entity_path,
             params: { date: @date.iso8601, mood: 'positive' },
             headers: { 'HTTP_REFERER' => monthlylog_url(monthlylog) }
      end

      assert_redirected_to monthlylog_path(monthlylog)
    end
  end
end
