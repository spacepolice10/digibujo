# frozen_string_literal: true

require 'test_helper'

class TrackersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @monthlylog = create_monthlylog!(@user, name: Date.current.strftime('%B %Y'))
    @tracker = create_tracker!(@user, name: 'Run', monthlylog: @monthlylog)
  end

  test 'show renders lifetime statistics and month heatmap' do
    @tracker.statuses.create!(date: Date.current, completed_at: Time.current)

    get tracker_path(@tracker)

    assert_response :success
    heatmap_days = @monthlylog.spread_days
    scheduled_count = heatmap_days.count { |day| @tracker.scheduled_on?(day) }

    assert_select '.tracker--statistics dt', text: 'Current streak'
    assert_select '.tracker--heatmap-date', count: heatmap_days.size
    assert_select '.tracker--heatmap-form', count: scheduled_count
  end

  test 'create tracker via monthlylog' do
    assert_difference -> { @monthlylog.trackers.count }, 1 do
      post monthlylog_trackers_path(@monthlylog), params: {
        tracker: { name: 'Read', schedule_days: %w[1 2 3 4 5], colour: 'cobalt', icon: 'books' }
      }
    end

    created = Tracker.order(:id).last
    assert_redirected_to monthlylog_path(@monthlylog)
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
  end

  test 'destroy redirects to monthlylog' do
    @tracker.statuses.create!(date: Date.current, completed_at: Time.current)

    assert_difference -> { Tracker.count }, -1 do
      delete tracker_path(@tracker)
    end

    assert_redirected_to monthlylog_path(@monthlylog)
  end
end
