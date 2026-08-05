# frozen_string_literal: true

require 'test_helper'

module Bullets
  class PostponesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @daylog = ensure_daylog!(@user)
      @future = ensure_future!(@user)
      @monthlylog = create_monthlylog!(@user, name: 'monthly')
    end

    test 'new renders postpone picker for selected bullets' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Schedule me'))

      get new_postpone_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_select 'turbo-frame#postpone_picker_dropdown_id'
      assert_select 'turbo-frame#postpone_picker_dropdown_id button[data-grid-navigation-target=?]', 'item', count: 6
      assert_select 'turbo-frame#postpone_picker_dropdown_id label[data-grid-navigation-target=?]', 'item', count: 1
      assert_select 'turbo-frame#postpone_picker_dropdown_id input[name="bullet_ids"][data-bulk-menu-target="idList"]',
                    count: 7
      assert_select 'turbo-frame#postpone_picker_dropdown_id input[name=bucket_id]', minimum: 5
      assert_select 'turbo-frame#postpone_picker_dropdown_id input[type=date][name=pops_on]'

      assert_match 'ASAP', response.body
      assert_match 'Tomorrow', response.body
      assert_match 'Next week', response.body
      assert_match 'Sometime', response.body
      assert_match Date.current.next_occurring(:monday).strftime('%a, %b %-d'), response.body
    end

    test 'new renders picker content inside turbo frame request' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Schedule me'))

      get new_postpone_path,
          params: { bullet_ids: card.id.to_s },
          headers: { 'Turbo-Frame' => 'postpone_picker_dropdown_id' }

      assert_response :success
      assert_select 'turbo-frame#postpone_picker_dropdown_id .dropdown--header h2', text: 'Schedule'
      assert_select 'turbo-frame#postpone_picker_dropdown_id button[data-grid-navigation-target=?]', 'item', count: 6
      assert_select 'input[name="bullet_ids"][data-bulk-menu-target="idList"]', count: 7
    end

    test 'new without bullet_ids returns not found' do
      get new_postpone_path

      assert_response :not_found
    end

    test 'create redirects to daylog and sets pop day' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Plan me'))
      target = 3.days.from_now.to_date

      post postpone_path, params: {
        bullet_ids: card.id.to_s,
        bucket_id: @daylog.id,
        pops_on: target.iso8601
      }

      assert_redirected_to daylog_path
      assert_equal target, card.reload.pops_on
      assert_equal @daylog.id, card.bucket_id
    end

    test 'create sometime parks on future unplanned' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Someday'))

      post postpone_path, params: {
        bullet_ids: card.id.to_s,
        bucket_id: @future.bucket.id
      }

      assert_redirected_to daylog_path
      card.reload
      assert_equal @future.bucket.id, card.bucket_id
      assert_nil card.pops_on
      assert_equal 'rescheduled', card.last_migration['action']
    end

    test 'create requires bucket_id' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Needs destination'))
      target = 1.week.from_now.to_date

      post postpone_path,
           params: { bullet_ids: card.id.to_s, pops_on: target.iso8601 },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :unprocessable_entity
      assert_equal Date.current, card.reload.pops_on
    end

    test 'create with pops_on one day ahead acts as postpone from bullet pop day' do
      anchor = 5.days.from_now.to_date
      card = create_bullet!(@user,
                            bulletable: Task.new(body: 'Defer me'),
                            pops_on: anchor)

      post postpone_path, params: {
        bullet_ids: card.id.to_s,
        bucket_id: @daylog.id,
        pops_on: (anchor + 1.day).iso8601
      }

      assert_redirected_to daylog_path
      assert_equal anchor + 1.day, card.reload.pops_on
    end

    test 'create with pops_on from daylog viewing day acts as postpone from that anchor' do
      view_day = Date.current
      card = create_bullet!(@user,
                            bulletable: Task.new(body: 'Triage'),
                            pops_on: 2.weeks.from_now.to_date)

      post postpone_path, params: {
        bullet_ids: card.id.to_s,
        bucket_id: @daylog.id,
        pops_on: (view_day + 1.day).iso8601
      }

      assert_redirected_to daylog_path
      assert_equal view_day + 1.day, card.reload.pops_on
    end

    test 'create with pops_on one week ahead' do
      view_day = Date.current
      card = create_bullet!(@user, bulletable: Event.new(body: 'Later'), pops_on: Date.current)

      post postpone_path, params: {
        bullet_ids: card.id.to_s,
        bucket_id: @daylog.id,
        pops_on: (view_day + 1.week).iso8601
      }

      assert_redirected_to daylog_path
      assert_equal view_day + 1.week, card.reload.pops_on
    end

    test 'create postpones multiple bullets to same day' do
      target = 4.days.from_now.to_date
      first = create_bullet!(@user, bulletable: Task.new(body: 'A'))
      second = create_bullet!(@user, bulletable: Note.new(body: 'B'))

      post postpone_path, params: {
        bullet_ids: "#{first.id},#{second.id}",
        bucket_id: @daylog.id,
        pops_on: target.iso8601
      }

      assert_redirected_to daylog_path
      assert_equal target, first.reload.pops_on
      assert_equal target, second.reload.pops_on
    end

    test 'create turbo stream removes postponed bullets and shows scheduled notice' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Plan me'))
      target = 3.days.from_now.to_date

      post postpone_path,
           params: {
             bullet_ids: card.id.to_s,
             bucket_id: @daylog.id,
             pops_on: target.iso8601
           },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_equal target, card.reload.pops_on
      assert_match %(turbo-stream action="update" target="toasts"), response.body
      assert_match "Bullet scheduled for #{target.strftime('%B %d')}", response.body
      assert_match %(turbo-stream action="remove" targets="#bullet_#{card.id}"), response.body
    end

    test 'create returns unprocessable entity for invalid pops_on' do
      card = create_bullet!(@user, bulletable: Task.new(body: 'Bad date'))
      original_pops_on = card.pops_on

      post postpone_path,
           params: {
             bullet_ids: card.id.to_s,
             bucket_id: @daylog.id,
             pops_on: 'not-a-date'
           },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :unprocessable_entity
      assert_equal original_pops_on, card.reload.pops_on
      assert_match %(turbo-stream action="update" target="toasts"), response.body
    end

    test 'create returns no content for monthlylog drag drop' do
      monthlylog = create_monthlylog!(@user, name: 'june')
      day = Date.current.beginning_of_month + 2.days
      card = create_bullet!(@user,
                            bulletable: Task.new(body: 'Plan in spread'),
                            bucket_id: monthlylog.bucket.id)

      post postpone_path,
           params: {
             bullet_ids: card.id.to_s,
             bucket_id: monthlylog.bucket.id,
             pops_on: day.iso8601
           },
           headers: {
             'Accept' => 'text/vnd.turbo-stream.html',
             'X-Requested-With' => 'pops-drop'
           }

      assert_response :no_content
      assert_equal day, card.reload.pops_on
      assert_equal monthlylog.bucket.id, card.bucket_id
      assert_empty response.body
    end
  end
end
