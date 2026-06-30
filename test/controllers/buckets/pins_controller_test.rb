# frozen_string_literal: true

require 'test_helper'

module Buckets
  class PinsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'alpha')
      @bucket = @collection.bucket
    end

    test 'create pins bucket and updates pin button via turbo stream' do
      assert_difference -> { Activity.count }, 1 do
        post buckets_pin_path,
             params: { bucket_id: @bucket.id },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end

      assert_response :success
      assert @bucket.reload.pinned?
      assert_equal 'pinned', Activity.order(:created_at).last.action
      assert_match 'turbo-stream', response.media_type
      assert_match dom_id(@bucket, :pin_button), response.body
    end

    test 'destroy unpins bucket and updates pin button via turbo stream' do
      @bucket.pin!

      assert_difference -> { Activity.count }, 1 do
        delete buckets_pin_path,
               params: { bucket_id: @bucket.id },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end

      assert_response :success
      assert_not @bucket.reload.pinned?
      assert_equal 'unpinned', Activity.order(:created_at).last.action
      assert_match dom_id(@bucket, :pin_button), response.body
    end

    test 'create redirects html requests back to home' do
      post buckets_pin_path, params: { bucket_id: @bucket.id }

      assert_redirected_to home_path
      assert @bucket.reload.pinned?
    end
  end
end
