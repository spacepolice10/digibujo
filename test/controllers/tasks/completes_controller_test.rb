# frozen_string_literal: true

require 'test_helper'

module Tasks
  class CompletesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = @user.bullets.create!(bulletable: Task.new(body: 'Finish me'))
    end

    test 'bulk create completes selected tasks via turbo stream' do
      second = @user.bullets.create!(bulletable: Task.new(body: 'Also finish'))

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
      monthlylog = create_monthlylog!(@user, name: 'june')
      bullet = @user.bullets.create!(
        bulletable: Task.new(body: 'Spread task'),
        bucket_id: monthlylog.bucket.id
      )

      post complete_path,
           params: { bullet_ids: bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert bullet.reload.bulletable.completed?
      assert_match 'data-task-completed="true"', response.body
      assert_match 'bullet--marker-select', response.body
    end
  end
end
