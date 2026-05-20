# frozen_string_literal: true

require "test_helper"

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show returns success" do
    get buckets_path
    assert_response :success
  end
end
