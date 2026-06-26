# frozen_string_literal: true

require 'test_helper'

module MonthlyBuckets
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    end

    test 'new renders trimmed monthly form inside matching composer frame' do
      get new_monthly_bucket_bullet_path(@monthly_bucket, bulletable_type: 'Task'),
          headers: { 'Turbo-Frame' => 'composer_unplanned' }

      assert_response :success
      assert_select 'turbo-frame#composer_unplanned form.monthly-bucket--bullet-form.bullet-form'
      assert_select 'turbo-frame#composer_unplanned lexxy-editor[preset=?]', 'inline'
      assert_select 'turbo-frame#composer_unplanned input[name=?]', 'bullet[composer_id]'
      assert_select 'turbo-frame#composer_unplanned select[name=?]', 'bullet[bulletable_type]', count: 0
      assert_select 'turbo-frame#composer_unplanned .mood-picker', count: 0
    end

    test 'new note uses inline editor in trimmed monthly form' do
      get new_monthly_bucket_bullet_path(@monthly_bucket, bulletable_type: 'Note'),
          headers: { 'Turbo-Frame' => 'composer_unplanned' }

      assert_response :success
      assert_select 'turbo-frame#composer_unplanned lexxy-editor[preset=?]', 'inline'
      assert_select 'turbo-frame#composer_unplanned .bullet-form-expand', count: 0
      assert_select 'turbo-frame#composer_unplanned .mood-picker', count: 0
    end

    test 'new with pops_on uses dated composer frame' do
      day = Date.current.beginning_of_month + 2.days
      frame_id = "composer_#{day.iso8601}"

      get new_monthly_bucket_bullet_path(@monthly_bucket, pops_on: day.iso8601, bulletable_type: 'Event'),
          headers: { 'Turbo-Frame' => frame_id }

      assert_response :success
      assert_select "turbo-frame##{frame_id} form.monthly-bucket--bullet-form"
      assert_select "turbo-frame##{frame_id} input[name='bullet[pops_on]'][value=?]", day.iso8601
      assert_select "turbo-frame##{frame_id} input[name='bullet[bulletable_type]'][value=?]", 'Event'
    end

    test 'create prepends bullet before composer frame' do
      assert_difference -> { @user.bullets.count }, 1 do
        post monthly_bucket_bullets_path(@monthly_bucket),
             params: {
               bullet: {
                 body: 'Brain dump idea',
                 bulletable_type: 'Task',
                 bucket_id: @monthly_bucket.bucket.id,
                 composer_id: 'composer_unplanned'
               }
             },
             as: :turbo_stream
      end

      assert_response :success
      assert_turbo_stream action: 'before', target: 'composer_unplanned'
      assert_turbo_stream action: 'update', target: 'composer_unplanned'
      assert_match 'Brain dump idea', response.body
      assert_match 'Add task', response.body
    end

    test 'create with add_another keeps composer open' do
      post monthly_bucket_bullets_path(@monthly_bucket),
           params: {
             add_another: '1',
             bullet: {
               body: 'Another idea',
               bulletable_type: 'Task',
               bucket_id: @monthly_bucket.bucket.id,
               composer_id: 'composer_unplanned'
             }
           },
           as: :turbo_stream

      assert_response :success
      assert_turbo_stream action: 'before', target: 'composer_unplanned'
      assert_no_turbo_stream action: 'update', target: 'composer_unplanned'
    end
  end
end
