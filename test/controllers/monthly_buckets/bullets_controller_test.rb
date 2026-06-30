# frozen_string_literal: true

require 'test_helper'

module MonthlyBuckets
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    end

    test 'new renders composer form inside matching composer frame' do
      frame_id = dom_id(@monthly_bucket)

      get new_monthly_bucket_bullet_path(@monthly_bucket, bulletable_type: 'Task'),
          headers: { 'Turbo-Frame' => frame_id }

      assert_response :success
      assert_select "turbo-frame##{frame_id} form.bullet-composer"
      assert_select "turbo-frame##{frame_id} lexxy-editor[preset=?]", 'inline'
      assert_select "turbo-frame##{frame_id} select.bullet-composer-type-select", count: 0
    end

    test 'new note uses note editor in composer form' do
      frame_id = dom_id(@monthly_bucket)

      get new_monthly_bucket_bullet_path(@monthly_bucket, bulletable_type: 'Note'),
          headers: { 'Turbo-Frame' => frame_id }

      assert_response :success
      assert_select "turbo-frame##{frame_id} lexxy-editor[preset=?]", 'note'
      assert_select "turbo-frame##{frame_id} lexxy-editor[preset=?][autofocus][placeholder]", "note"
      assert_select "turbo-frame##{frame_id} .mood-picker"
    end

    test 'new with pops_on uses dated composer frame' do
      day = Date.current.beginning_of_month + 2.days
      frame_id = dom_id(@monthly_bucket, day)

      get new_monthly_bucket_bullet_path(@monthly_bucket, pops_on: day.iso8601, bulletable_type: 'Event'),
          headers: { 'Turbo-Frame' => frame_id }

      assert_response :success
      assert_select "turbo-frame##{frame_id} form.bullet-composer"
      assert_select "turbo-frame##{frame_id} input[name='bullet[pops_on]'][value=?]", day.iso8601
      assert_select "turbo-frame##{frame_id} input[name='bullet[bulletable_type]'][value=?]", 'Event'
    end

    test 'create appends bullet into composer frame' do
      frame_id = dom_id(@monthly_bucket)

      assert_difference -> { @user.bullets.count }, 1 do
        post monthly_bucket_bullets_path(@monthly_bucket),
             params: {
               bullet: {
                 body: 'Brain dump idea',
                 bulletable_type: 'Task'
               }
             },
             as: :turbo_stream
      end

      assert_response :success
      assert_turbo_stream action: 'append', target: frame_id
      assert_match 'Brain dump idea', response.body
    end

    test 'create with another keeps composer open' do
      frame_id = dom_id(@monthly_bucket)

      post monthly_bucket_bullets_path(@monthly_bucket),
           params: {
             another: '1',
             bullet: {
               body: 'Another idea',
               bulletable_type: 'Task'
             }
           },
           as: :turbo_stream

      assert_response :success
      assert_turbo_stream action: 'append', target: frame_id
    end
  end
end
