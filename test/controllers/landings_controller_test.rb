# frozen_string_literal: true

require 'test_helper'

class LandingsControllerTest < ActionDispatch::IntegrationTest
  test 'show is available without authentication' do
    get landing_path

    assert_response :success
  end
end
