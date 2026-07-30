# frozen_string_literal: true

require 'test_helper'

class TrackersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @tracker = create_tracker!(@user, name: 'Run')
    @calendar_date = @user.calendar_dates.create!(date: Date.current)
  end

  test 'show renders lifetime statistics and last 30 days heatmap' do
    @tracker.statuses.create!(calendar_date: @calendar_date, completed_at: Time.current)

    get tracker_path(@tracker)

    assert_response :success
    heatmap_days = (30.days.ago.to_date..Date.current).to_a
    scheduled_count = heatmap_days.count { |day| @tracker.scheduled_on?(day) }

    assert_select '.tracker--statistics dt', text: 'Current streak'
    assert_select '.tracker--heatmap-date', count: heatmap_days.size
    assert_select '.tracker--heatmap-form', count: scheduled_count
  end

  test 'create tracker' do
    assert_difference -> { @user.trackers.count }, 1 do
      post trackers_path, params: {
        tracker: { name: 'Read', schedule_days: %w[1 2 3 4 5], colour: 'cobalt', icon: 'books' }
      }
    end

    created = Tracker.order(:id).last
    assert_redirected_to root_path
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

  test 'destroy redirects to root' do
    @tracker.statuses.create!(calendar_date: @calendar_date, completed_at: Time.current)

    assert_difference -> { Tracker.count }, -1 do
      delete tracker_path(@tracker)
    end

    assert_redirected_to root_path
  end
end
