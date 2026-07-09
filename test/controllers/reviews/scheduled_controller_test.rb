# frozen_string_literal: true

require 'test_helper'

module Reviews
  class ScheduledControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @today = Date.current
    end

    test 'show lists scheduled bullets for the week anchored at review_to' do
      week_start = @today + 2.days
      @user.bullets.create!(bulletable: Event.new(body: 'Team standup'), pops_on: week_start)

      get review_scheduled_path(from: @today.iso8601, to: @today.iso8601)

      assert_response :success
      assert_match 'Team standup', response.body
      assert_select '[data-controller="pops-drop"]', minimum: 7
    end

    test 'show only includes active bullets' do
      @user.bullets.create!(bulletable: Task.new(body: 'Active bullet'), pops_on: @today)
      archived = @user.bullets.create!(bulletable: Task.new(body: 'Archived'), pops_on: @today)
      archived.archive!

      get review_scheduled_path(from: @today.iso8601, to: @today.iso8601)

      assert_response :success
      assert_match 'Active bullet', response.body
      assert_no_match 'Archived', response.body
    end

    test 'show defaults review period when no dates given' do
      @user.bullets.create!(bulletable: Task.new(body: 'Recent'), pops_on: @today)

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
