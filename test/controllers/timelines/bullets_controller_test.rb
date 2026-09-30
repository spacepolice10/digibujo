# frozen_string_literal: true

require 'test_helper'

module Timelines
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test 'before returns the older page wrapped in its sections' do
      old = create_bullet!(@user, body: 'Old row', pops_on: Date.current - 20)
      cursor = create_bullet!(@user, body: 'Cursor row')

      get timeline_bullets_path(before: cursor.id)

      assert_response :success
      assert_select 'section#timeline_section_last-month .bullet', text: /Old row/
      assert_no_match 'Cursor row', response.body
      assert_equal old.id, @user.bullets.find_by!(pops_on: Date.current - 20).id
    end

    test 'before repeats the boundary section so the client can merge it' do
      earlier = create_bullet!(@user, body: 'Earlier today', created_at: 2.hours.ago)
      cursor = create_bullet!(@user, body: 'Later today', created_at: 1.hour.ago)

      get timeline_bullets_path(before: cursor.id)

      assert_response :success
      assert_select 'section#timeline_section_today .bullet', text: /#{earlier.name}/
    end

    test 'before returns no content when nothing older exists' do
      cursor = create_bullet!(@user, body: 'Only row')

      get timeline_bullets_path(before: cursor.id)

      assert_response :no_content
    end

    test 'before returns no content for an unknown cursor' do
      get timeline_bullets_path(before: 0)

      assert_response :no_content
    end

    test 'before ignores another users bullets' do
      foreign = create_bullet!(users(:two), body: 'Theirs')

      get timeline_bullets_path(before: foreign.id)

      assert_response :no_content
    end

    test 'before skips collected bullets' do
      create_bullet!(@user, body: 'Filed row', pops_on: Date.current - 3, collection: create_collection!(@user, name: 'Work'))
      cursor = create_bullet!(@user, body: 'Cursor row')

      get timeline_bullets_path(before: cursor.id)

      assert_response :no_content
    end
  end
end
