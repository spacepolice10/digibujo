# frozen_string_literal: true

require 'test_helper'

module Tasks
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
      assert @bullet.reload.bulletable.completed?
      assert second.reload.bulletable.completed?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
      assert_match %(turbo-stream action="replace" targets="#bullet_#{second.id}"), response.body
    end

    test 'bulk destroy uncompletes selected tasks' do
      @bullet.bulletable.complete!

      delete complete_path,
             params: { bullet_ids: @bullet.id.to_s },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @bullet.reload.bulletable.completed?
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
      assert bullet.reload.bulletable.completed?
      assert_match 'data-bullet-completed', response.body
      assert_match 'bullet--marker-slot', response.body
    end
  end
end
