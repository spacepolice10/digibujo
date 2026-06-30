# frozen_string_literal: true

require 'test_helper'

module Collections
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'Inbox')
    end

    test 'new renders composer form in collection frame' do
      get new_collection_bullet_path(@collection, bulletable_type: 'Task'),
          headers: { 'Turbo-Frame' => 'bullet_composer' }

      assert_response :success
      assert_select 'turbo-frame#bullet_composer form.bullet-composer'
      assert_select 'turbo-frame#bullet_composer input[name=?]', 'bullet[bucket_id]'
    end

    test 'create appends collection bullet partial into bullets container' do
      assert_difference -> { @user.bullets.count }, 1 do
        post collection_bullets_path(@collection),
             params: {
               bullet: {
                 body: 'Collection task',
                 bulletable_type: 'Task'
               }
             },
             as: :turbo_stream
      end

      assert_response :success
      assert_turbo_stream action: 'append', target: 'bullets'
      assert_match 'Collection task', response.body
    end
  end
end
