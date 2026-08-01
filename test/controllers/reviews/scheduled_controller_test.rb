# frozen_string_literal: true

require 'test_helper'

module Reviews
  class ScheduledControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @today = Date.current
    end

    test 'show lists scheduled bullets for the week starting today' do
      week_start = @today + 2.days
      create_bullet!(@user, bulletable: Event.new(body: 'Team standup'), pops_on: week_start)

      get review_scheduled_path(from: (@today - 1.day).iso8601, to: (@today - 1.day).iso8601)

      assert_response :success
      assert_match 'Team standup', response.body
      assert_select '[data-controller~=pops-drop]', minimum: 7
      assert_select '[data-pops-drop-optimistic-value="drop-postpone-optimistic"]', minimum: 7
    end

    test 'show only includes active bullets' do
      create_bullet!(@user, bulletable: Task.new(body: 'Active bullet'), pops_on: @today)
      archived = create_bullet!(@user, bulletable: Task.new(body: 'Archived'), pops_on: @today)
      archived.archive!

      get review_scheduled_path(from: @today.iso8601, to: @today.iso8601)

      assert_response :success
      assert_match 'Active bullet', response.body
      assert_no_match 'Archived', response.body
    end

    test 'show defaults to the next seven days from today' do
      create_bullet!(@user, bulletable: Task.new(body: 'Recent'), pops_on: @today)

      get review_scheduled_path

      assert_response :success
      assert_match 'Recent', response.body
    end

    test 'show requires authentication' do
      sign_out
      get review_scheduled_path(from: @today.iso8601, to: @today.iso8601)
      assert_redirected_to new_authentication_path
    end
  end
end
