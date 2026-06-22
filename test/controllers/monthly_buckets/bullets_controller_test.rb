# frozen_string_literal: true

require 'test_helper'

module MonthlyBuckets
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    end

    test 'new renders bullet form inside matching composer frame' do
      get new_future_monthly_bucket_bullet_path(@monthly_bucket),
          headers: { 'Turbo-Frame' => 'composer_unplanned' }

      assert_response :success
      assert_select 'turbo-frame#composer_unplanned.bullet-form, turbo-frame#composer_unplanned .bullet-form'
      assert_select 'turbo-frame#composer_unplanned input[name=?]', 'bullet[composer_id]'
    end

    test 'new with pops_on uses dated composer frame' do
      day = Date.current.beginning_of_month + 2.days
      frame_id = "composer_#{day.iso8601}"

      get new_future_monthly_bucket_bullet_path(@monthly_bucket, pops_on: day.iso8601, bulletable_type: 'Event'),
          headers: { 'Turbo-Frame' => frame_id }

      assert_response :success
      assert_select "turbo-frame##{frame_id} .bullet-form"
      assert_select "turbo-frame##{frame_id} input[name='bullet[pops_on]'][value=?]", day.iso8601
      assert_select "turbo-frame##{frame_id} select[name='bullet[bulletable_type]'] option[selected][value=?]",
                    'Event'
    end

    test 'create prepends bullet before composer frame' do
      assert_difference -> { @user.bullets.count }, 1 do
        post future_monthly_bucket_bullets_path(@monthly_bucket),
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
      assert_match 'Brain dump idea', response.body
    end
  end
end
