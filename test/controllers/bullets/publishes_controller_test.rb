# frozen_string_literal: true

require 'test_helper'

module Bullets
  class PublishesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = create_bullet!(@user, bulletable: Note.new(body: 'Publish me'))
    end

    test 'create publishes bullet via turbo stream' do
      post publish_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert @bullet.reload.published?
      assert_match 'turbo-stream', response.media_type
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
    end

    test 'create publishes multiple bullets' do
      other = create_bullet!(@user, bulletable: Note.new(body: 'Too'))

      post publish_path, params: { bullet_ids: "#{@bullet.id},#{other.id}" }

      assert_redirected_to bullet_path(@bullet)
      assert @bullet.reload.published?
      assert other.reload.published?
    end

    test 'destroy unpublishes bullet via turbo stream' do
      @bullet.publish!

      delete publish_path,
             params: { bullet_ids: @bullet.id.to_s },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @bullet.reload.published?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
    end
  end
end
