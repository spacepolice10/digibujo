# frozen_string_literal: true

require 'test_helper'

module Daylogs
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @selected_date = Date.current - 2.days
    end

    test 'new renders composer form inside bullet composer frame' do
      get new_daylog_bullet_path(date: @selected_date, bulletable_type: 'Task'),
          headers: { 'Turbo-Frame' => 'bullet_composer' }

      assert_response :success
      assert_select 'turbo-frame#bullet_composer form.bullet-composer'
      assert_select 'turbo-frame#bullet_composer lexxy-editor[preset=?]', 'inline'
      assert_select 'turbo-frame#bullet_composer .bullet-composer--type-pill[data-bullet-type=?]', 'task', text: /Task/
      assert_select 'turbo-frame#bullet_composer .bullet-composer--type-dismiss[data-action=?]', 'composer#cancel'
      assert_select 'turbo-frame#bullet_composer select.bullet-composer-type-select', count: 0
      assert_select "turbo-frame#bullet_composer input[name='bullet[pops_on]'][value=?]", @selected_date.iso8601
    end

    test 'new note uses note editor in composer form' do
      get new_daylog_bullet_path(date: @selected_date, bulletable_type: 'Note'),
          headers: { 'Turbo-Frame' => 'bullet_composer' }

      assert_response :success
      assert_select 'turbo-frame#bullet_composer lexxy-editor[preset=?]', 'note'
      assert_select 'turbo-frame#bullet_composer lexxy-editor[preset=?][autofocus][placeholder]', 'note'
      assert_select 'turbo-frame#bullet_composer .bullet-composer--type-pill[data-bullet-type=?]', 'note', text: /Note/
      assert_select 'turbo-frame#bullet_composer .bullet-composer--type-dismiss[data-action=?]', 'composer#cancel'
      assert_select 'turbo-frame#bullet_composer .mood-picker'
    end

    test 'new without date defaults to today' do
      get new_daylog_bullet_path(bulletable_type: 'Event'),
          headers: { 'Turbo-Frame' => 'bullet_composer' }

      assert_response :success
      assert_select "turbo-frame#bullet_composer input[name='bullet[pops_on]'][value=?]", Date.current.iso8601
    end

    test 'new with invalid date returns not found' do
      get new_daylog_bullet_path(date: "#{Date.current.year}-02-30", bulletable_type: 'Task'),
          headers: { 'Turbo-Frame' => 'bullet_composer' }

      assert_response :not_found
    end

    test 'create appends bullet into bullets container' do
      assert_difference -> { @user.bullets.count }, 1 do
        post daylog_bullets_path(date: @selected_date),
             params: {
               bullet: {
                 body: 'Daylog task',
                 bulletable_type: 'Task',
                 pops_on: @selected_date.iso8601
               }
             },
             as: :turbo_stream
      end

      assert_response :success
      assert_turbo_stream action: 'append', target: 'bullets'
      assert_match 'Daylog task', response.body
    end

    test 'create with another keeps composer open' do
      post daylog_bullets_path(date: @selected_date),
           params: {
             another: '1',
             bullet: {
               body: 'Another daylog task',
               bulletable_type: 'Task',
               pops_on: @selected_date.iso8601
             }
           },
           as: :turbo_stream

      assert_response :success
      assert_turbo_stream action: 'append', target: 'bullets'
    end
  end
end
