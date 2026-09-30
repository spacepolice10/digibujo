# frozen_string_literal: true

require 'test_helper'

module Bullets
  class CompletionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = create_bullet!(@user, body: 'Finish me')
    end

    test 'bulk create completes selected bullets via turbo stream' do
      second = create_bullet!(@user, body: 'Also finish')

      post completion_path,
           params: { bullet_ids: "#{@bullet.id},#{second.id}" },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert @bullet.reload.done?
      assert second.reload.done?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
      assert_match %(turbo-stream action="replace" targets="#bullet_#{second.id}"), response.body
      assert_match '2 bullets completed', response.body
    end

    test 'bulk destroy uncompletes selected bullets' do
      @bullet.complete!

      delete completion_path,
             params: { bullet_ids: @bullet.id.to_s },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @bullet.reload.done?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
      assert_match 'Bullet uncompleted', response.body
    end

    test 'completed bullets render as done' do
      post completion_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_match 'data-bullet-done="true"', response.body
    end

    test 'a collected bullet can be completed' do
      collection = create_collection!(@user, name: 'work')
      @bullet.collect!(collection_id: collection.id)

      post completion_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert @bullet.reload.done?
    end
  end
end
