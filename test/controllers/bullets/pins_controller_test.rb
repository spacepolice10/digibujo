# frozen_string_literal: true

require 'test_helper'

module Bullets
  class PinsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Pin me')
    end

    test 'create pins bullet via turbo stream' do
      post pin_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert @bullet.reload.pinned?
      assert_match 'turbo-stream', response.media_type
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
    end

    test 'create pins multiple bullets' do
      other = @user.bullets.create!(bulletable: Note.create!, body: 'Too')

      post pin_path, params: { bullet_ids: "#{@bullet.id},#{other.id}" }

      assert_redirected_to daylog_path(date: Date.current.iso8601)
      assert @bullet.reload.pinned?
      assert other.reload.pinned?
    end

    test 'destroy unpins bullet via turbo stream' do
      @user.bullets.create!(bulletable: Task.create!, body: 'Still pinned')
      @bullet.pin!

      delete pin_path,
             params: { bullet_ids: @bullet.id.to_s },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @bullet.reload.pinned?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
    end

    test 'create turbo stream replaces monthly bucket bullet with unified row' do
      monthly_bucket = create_monthly_bucket!(@user, name: 'june')
      bullet = @user.bullets.create!(
        bulletable: Task.create!,
        body: 'Spread task',
        bucket_id: monthly_bucket.bucket.id
      )

      post pin_path,
           params: { bullet_ids: bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert bullet.reload.pinned?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{bullet.id}"), response.body
      assert_match 'bullet--marker-slot', response.body
      assert_no_match 'bullet-compact', response.body
    end
  end
end
