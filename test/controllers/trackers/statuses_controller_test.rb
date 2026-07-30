# frozen_string_literal: true

require 'test_helper'

class Trackers::StatusesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @tracker = create_tracker!(@user, name: 'Run')
    @date = Date.current
    @calendar_date = @user.calendar_dates.create!(date: @date)
  end

  test 'create status' do
    assert_difference -> { @tracker.statuses.count }, 1 do
      post tracker_status_path(@tracker),
           params: { date: @date.iso8601, dom_key: 'date' },
           as: :turbo_stream
    end

    assert_response :success
    assert @tracker.statuses.joins(:calendar_date).exists?(calendar_dates: { date: @date })
    assert_select "turbo-stream[action=replace][target=#{dom_id(@tracker, "date_#{@date.iso8601}")}]", count: 1
    assert_select 'turbo-stream[action=replace]', count: 1
  end

  test 'create is idempotent' do
    @tracker.statuses.create!(calendar_date: @calendar_date, completed_at: 1.hour.ago)

    assert_no_difference -> { @tracker.statuses.count } do
      post tracker_status_path(@tracker),
           params: { date: @date.iso8601, dom_key: 'date' },
           as: :turbo_stream
    end

    assert_response :success
  end

  test 'create rejects unscheduled day' do
    @tracker.update!(schedule: { 'days' => [(@date + 1.day).wday] })

    assert_no_difference -> { @tracker.statuses.count } do
      post tracker_status_path(@tracker),
           params: { date: @date.iso8601, dom_key: 'date' },
           as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test 'destroy status' do
    @tracker.statuses.create!(calendar_date: @calendar_date, completed_at: Time.current)

    assert_difference -> { @tracker.statuses.count }, -1 do
      delete tracker_status_path(@tracker),
             params: { date: @date.iso8601, dom_key: 'date' },
             as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@tracker, "date_#{@date.iso8601}")}]", count: 1
  end

  test 'create status replaces monthlylog day toggle' do
    assert_difference -> { @tracker.statuses.count }, 1 do
      post tracker_status_path(@tracker),
           params: { date: @date.iso8601, dom_key: 'monthlylog' },
           as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@tracker, "date_#{@date.iso8601}")}]" do
      assert_select '.tracker--day-toggle-done'
    end
  end
end
