# frozen_string_literal: true

require 'test_helper'

class TrackersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @tracker = create_tracker!(@user, name: 'Run')
  end

  test 'show renders lifetime statistics and 90-day heatmap' do
    @tracker.completions.create!(date: Date.current, completed_at: Time.current)

    get tracker_path(@tracker)

    assert_response :success
    heatmap_days = (Date.current - 89.days)..Date.current
    scheduled_count = heatmap_days.count { |day| @tracker.scheduled_on?(day) }

    assert_select '.tracker--statistics dt', text: 'Current streak'
    assert_select '.tracker--statistics dt', text: 'Best streak'
    assert_select '.tracker--statistics dt', text: 'Total days'
    assert_select '.tracker--statistics dt', text: 'This month', count: 0
    assert_select '.tracker--heatmap-date', count: 90
    assert_select '.tracker--heatmap-form', count: scheduled_count
    assert_select '.tracker--heatmap-date-current', count: 1
    assert_select '.tracker--month-nav', count: 0
    assert_select '.tracker--grid', count: 0
  end

  test 'show heatmap reflects completions from the full 90-day range' do
    @tracker.update!(created_at: 10.days.ago)
    past_date = Date.current - 5.days
    @tracker.completions.create!(date: past_date, completed_at: 1.day.ago)

    get tracker_path(@tracker)

    assert_response :success
    assert_select "##{dom_id(@tracker, "date_#{past_date.iso8601}")} button.tracker--heatmap-date-done"
  end

  test 'show renders clickable heatmap buttons' do
    get tracker_path(@tracker)

    assert_response :success
    heatmap_days = (Date.current - 89.days)..Date.current
    scheduled_count = heatmap_days.count { |day| @tracker.scheduled_on?(day) }

    assert_select '.tracker--heatmap-date', count: 90
    assert_select '.tracker--heatmap-form', count: scheduled_count
    assert_select '.tracker--heatmap-date-disabled', count: 90 - scheduled_count
    assert_select ".tracker--heatmap-cell [popover='hint']", count: 90
  end

  test 'show disables heatmap buttons for unscheduled days' do
    @tracker.update!(schedule: { 'days' => [Date.current.wday] }, created_at: 90.days.ago)

    get tracker_path(@tracker)

    assert_response :success
    heatmap_days = (Date.current - 89.days)..Date.current
    scheduled_count = heatmap_days.count { |day| @tracker.scheduled_on?(day) }

    assert_select '.tracker--heatmap-form', count: scheduled_count
    assert_select '.tracker--heatmap-date-disabled', count: 90 - scheduled_count
    assert_select ".tracker--heatmap-cell [popover='hint']", text: /Not scheduled/
  end

  test 'create tracker' do
    assert_difference -> { @user.trackers.count }, 1 do
      post trackers_path, params: {
        tracker: { name: 'Read', schedule_days: %w[1 2 3 4 5], colour: 'cobalt', icon: 'books' }
      }
    end

    created = Tracker.order(:id).last
    assert_redirected_to home_path
    assert_equal [1, 2, 3, 4, 5], created.schedule_days
    assert_equal 'cobalt', created.colour
    assert_equal 'books', created.icon
  end

  test 'update tracker' do
    @tracker.update!(colour: 'teal', icon: 'muscle')

    patch tracker_path(@tracker), params: {
      tracker: { name: 'Morning run', schedule_days: %w[0 6] }
    }

    assert_redirected_to tracker_path(@tracker)
    @tracker.reload
    assert_equal 'Morning run', @tracker.name
    assert_equal [0, 6], @tracker.schedule_days
    assert_equal 'teal', @tracker.colour
    assert_equal 'muscle', @tracker.icon
  end

  test 'destroy succeeds with completions' do
    @tracker.completions.create!(date: Date.current, completed_at: Time.current)

    assert_difference -> { Tracker.count }, -1 do
      delete tracker_path(@tracker)
    end

    assert_redirected_to home_path
  end

  test 'destroy succeeds without completions' do
    assert_difference -> { Tracker.count }, -1 do
      delete tracker_path(@tracker)
    end

    assert_redirected_to home_path
  end
end
