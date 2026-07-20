# frozen_string_literal: true

require 'test_helper'

module Bullets
  class PinsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = create_bullet!(@user, bulletable: Task.new(body: 'Pin me'))
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
      other = create_bullet!(@user, bulletable: Note.new(body: 'Too'))

      post pin_path, params: { bullet_ids: "#{@bullet.id},#{other.id}" }

      assert_redirected_to daylog_path
      assert @bullet.reload.pinned?
      assert other.reload.pinned?
    end

    test 'destroy unpins bullet via turbo stream' do
      create_bullet!(@user, bulletable: Task.new(body: 'Still pinned'))
      @bullet.pin!

      delete pin_path,
             params: { bullet_ids: @bullet.id.to_s },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @bullet.reload.pinned?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
    end

    test 'create turbo stream replaces monthly bucket bullet with unified row' do
      monthlylog = create_monthlylog!(@user, name: 'june')
      bullet = create_bullet!(@user,
        bulletable: Task.create!(body: 'Spread task'),
        bucket_id: monthlylog.bucket.id
      )

      post pin_path,
           params: { bullet_ids: bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert bullet.reload.pinned?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{bullet.id}"), response.body
      assert_match 'bullet--marker-select', response.body
      assert_no_match 'bullet-compact', response.body
    end
  end
end
