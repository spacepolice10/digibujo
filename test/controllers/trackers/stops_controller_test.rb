# frozen_string_literal: true

require 'test_helper'

class Trackers::StopsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @tracker = create_tracker!(@user, name: 'Run')
  end

  test 'create stops tracker' do
    post tracker_stop_path(@tracker)

    assert_redirected_to tracker_path(@tracker)
    assert_equal Date.current, @tracker.reload.stopped_on
  end
end
