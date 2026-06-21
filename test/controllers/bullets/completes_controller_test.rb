# frozen_string_literal: true

require 'test_helper'

module Bullets
  class CompletesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Finish me')
    end

    test 'bulk create completes selected tasks via turbo stream' do
      second = @user.bullets.create!(bulletable: Task.create!, body: 'Also finish')

      post complete_path,
           params: { bullet_ids: "#{@bullet.id},#{second.id}" },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert @bullet.reload.bulletable.done?
      assert second.reload.bulletable.done?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
      assert_match %(turbo-stream action="replace" targets="#bullet_#{second.id}"), response.body
    end

    test 'bulk create rejects non-task bullets' do
      note = @user.bullets.create!(bulletable: Note.create!, body: 'Just a note')

      post complete_path,
           params: { bullet_ids: "#{@bullet.id},#{note.id}" },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :unprocessable_entity
      assert_not @bullet.reload.bulletable.done?
      assert_match %(turbo-stream action="update" target="toasts"), response.body
      assert_match 'Only tasks can be completed', response.body
    end

    test 'bulk destroy uncompletes selected tasks' do
      @bullet.bulletable.complete!

      delete complete_path,
             params: { bullet_ids: @bullet.id.to_s },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @bullet.reload.bulletable.done?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
    end

    test 'bulk complete replaces monthly bucket bullet with unified row' do
      monthly_bucket = create_monthly_bucket!(@user, name: 'june')
      bullet = @user.bullets.create!(
        bulletable: Task.create!,
        body: 'Spread task',
        bucket_id: monthly_bucket.bucket.id
      )

      post complete_path,
           params: { bullet_ids: bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert bullet.reload.bulletable.done?
      assert_match 'data-bullet-completed', response.body
      assert_match 'bullet--marker-slot', response.body
    end
  end
end
