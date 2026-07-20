# frozen_string_literal: true

require 'test_helper'

class CurrentTimezoneTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
  end

  test 'includes the timezone cookie in the ETag' do
    cookies[:timezone] = 'America/New_York'
    get daylog_path
    etag = response.headers.fetch('ETag')

    get daylog_path, headers: { 'If-None-Match' => etag }
    assert_equal 304, response.status

    cookies[:timezone] = 'America/Los_Angeles'
    get daylog_path, headers: { 'If-None-Match' => etag }
    assert_response :success
    assert_not_equal etag, response.headers.fetch('ETag')
  end
end
