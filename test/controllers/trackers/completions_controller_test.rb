# frozen_string_literal: true

require 'test_helper'

class Trackers::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @tracker = create_tracker!(@user, name: 'Run')
    @date = Date.current
  end

  test 'create completion' do
    assert_difference -> { @tracker.completions.count }, 1 do
      post tracker_completion_path(@tracker),
           params: { date: @date.iso8601, dom_key: 'date' },
           as: :turbo_stream
    end

    assert_response :success
    assert @tracker.completions.exists?(date: @date)
    assert_select "turbo-stream[action=replace][target=#{dom_id(@tracker, "date_#{@date.iso8601}")}]", count: 1
    assert_select 'turbo-stream[action=replace]', count: 1
  end

  test 'create is idempotent' do
    @tracker.completions.create!(date: @date, completed_at: 1.hour.ago)

    assert_no_difference -> { @tracker.completions.count } do
      post tracker_completion_path(@tracker),
           params: { date: @date.iso8601, dom_key: 'date' },
           as: :turbo_stream
    end

    assert_response :success
  end

  test 'create rejects unscheduled day' do
    @tracker.update!(schedule: { 'days' => [(@date + 1.day).wday] })

    assert_no_difference -> { @tracker.completions.count } do
      post tracker_completion_path(@tracker),
           params: { date: @date.iso8601, dom_key: 'date' },
           as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test 'destroy completion' do
    @tracker.completions.create!(date: @date, completed_at: Time.current)

    assert_difference -> { @tracker.completions.count }, -1 do
      delete tracker_completion_path(@tracker),
             params: { date: @date.iso8601, dom_key: 'date' },
             as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@tracker, "date_#{@date.iso8601}")}]", count: 1
  end
end
