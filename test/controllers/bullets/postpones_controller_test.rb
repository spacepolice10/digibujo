# frozen_string_literal: true

require 'test_helper'

module Bullets
  class PostponesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test 'new renders postpone picker for selected bullets' do
      card = create_bullet!(@user, body: 'Schedule me')

      get new_postpone_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_select 'turbo-frame#postpone_picker_dropdown_id[popover]'
      assert_select 'turbo-frame#postpone_picker_dropdown_id.dropdown', count: 0
      assert_select 'turbo-frame#postpone_picker_dropdown_id button[data-grid-navigation-target=?]', 'item', count: 5
      assert_select 'turbo-frame#postpone_picker_dropdown_id label[data-grid-navigation-target=?]', 'item', count: 1
      assert_select 'turbo-frame#postpone_picker_dropdown_id input[name="bullet_ids"][data-bulk-menu-target="idList"]',
                    count: 6
      assert_select 'turbo-frame#postpone_picker_dropdown_id input[type=date][name=pops_on]'
      assert_select 'turbo-frame#postpone_picker_dropdown_id input[name=bucket_id]', count: 0

      assert_match 'Today', response.body
      assert_match 'Tomorrow', response.body
      assert_match 'Next week', response.body
      assert_match Date.current.next_occurring(:monday).strftime('%a, %b %-d'), response.body
    end

    test 'new renders picker content inside turbo frame request' do
      card = create_bullet!(@user, body: 'Schedule me')

      get new_postpone_path,
          params: { bullet_ids: card.id.to_s },
          headers: { 'Turbo-Frame' => 'postpone_picker_dropdown_id' }

      assert_response :success
      assert_select 'turbo-frame#postpone_picker_dropdown_id h2', text: 'Schedule'
      assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]', count: 6
    end

    test 'new without bullet_ids returns not found' do
      get new_postpone_path

      assert_response :not_found
    end

    test 'create redirects to the timeline and sets the pop day' do
      card = create_bullet!(@user, body: 'Plan me')
      target = 3.days.from_now.to_date

      post postpone_path, params: { bullet_ids: card.id.to_s, pops_on: target.iso8601 }

      assert_redirected_to bullets_path
      assert_equal target, card.reload.pops_on
    end

    test 'create records the rescheduling activity' do
      card = create_bullet!(@user, body: 'Plan me')
      target = 3.days.from_now.to_date

      assert_difference -> { Activity.where(action: 'rescheduled').count }, 1 do
        post postpone_path, params: { bullet_ids: card.id.to_s, pops_on: target.iso8601 }
      end
    end

    test 'create requires pops_on' do
      card = create_bullet!(@user, body: 'Needs a day')

      post postpone_path,
           params: { bullet_ids: card.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :unprocessable_entity
      assert_equal Date.current, card.reload.pops_on
    end

    test 'create keeps collection membership' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, body: 'Filed', collection: collection)
      target = 2.days.from_now.to_date

      post postpone_path, params: { bullet_ids: card.id.to_s, pops_on: target.iso8601 }

      assert_includes card.reload.collections, collection
      assert_equal target, card.pops_on
    end

    test 'create postpones multiple bullets to same day' do
      target = 4.days.from_now.to_date
      first = create_bullet!(@user, body: 'A')
      second = create_bullet!(@user, body: 'B')

      post postpone_path, params: { bullet_ids: "#{first.id},#{second.id}", pops_on: target.iso8601 }

      assert_redirected_to bullets_path
      assert_equal target, first.reload.pops_on
      assert_equal target, second.reload.pops_on
    end

    test 'create turbo stream removes postponed bullets and shows scheduled notice' do
      card = create_bullet!(@user, body: 'Plan me')
      target = 3.days.from_now.to_date

      post postpone_path,
           params: { bullet_ids: card.id.to_s, pops_on: target.iso8601 },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_equal target, card.reload.pops_on
      assert_match %(turbo-stream action="update" target="toasts"), response.body
      assert_match "Bullet scheduled for #{target.strftime('%B %-d')}", response.body
      assert_match %(turbo-stream action="remove" targets="#bullet_#{card.id}"), response.body
      assert_no_match 'timeline_section_current_date', response.body
    end

    test 'create turbo stream brings a future bullet back onto today' do
      card = create_bullet!(@user, body: 'Due now', pops_on: 3.days.from_now.to_date)

      post postpone_path,
           params: { bullet_ids: card.id.to_s, pops_on: Date.current.iso8601 },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_match %(turbo-stream action="append" target="timeline_section_current_date"), response.body
    end

    test 'create returns unprocessable entity for invalid pops_on' do
      card = create_bullet!(@user, body: 'Bad date')
      original_pops_on = card.pops_on

      post postpone_path,
           params: { bullet_ids: card.id.to_s, pops_on: 'not-a-date' },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :unprocessable_entity
      assert_equal original_pops_on, card.reload.pops_on
      assert_match %(turbo-stream action="update" target="toasts"), response.body
    end
  end
end
