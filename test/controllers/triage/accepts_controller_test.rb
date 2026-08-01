# frozen_string_literal: true

require 'test_helper'

module Triage
  class AcceptsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @daylog = ensure_daylog!(@user)
      @pending = Pending.provision!(@user)
      @bullet = create_bullet!(
        @user,
        bucket: @pending.bucket,
        bulletable: Note.new(body: 'Capture me'),
        pops_on: nil
      )
    end

    test 'create moves pending bullet into today daylog' do
      assert_changes -> { @bullet.reload.bucket_id }, to: @daylog.id do
        assert_changes -> { @bullet.reload.pops_on }, to: Date.current do
          post triage_bullet_accept_path(@bullet), as: :turbo_stream
        end
      end

      assert_response :success
      assert @bullet.reload.rescheduled_migration?
      assert_match 'Added to today', response.body
      assert_match %(turbo-stream action="remove" target="#{ActionView::RecordIdentifier.dom_id(@bullet, :triage)}"), response.body
    end

    test 'create moves monthlylog today bullet into daylog' do
      monthlylog = create_monthlylog!(@user, name: 'This month')
      bullet = create_bullet!(
        @user,
        bucket: monthlylog.bucket,
        bulletable: Task.new(body: 'From monthly'),
        pops_on: Date.current
      )

      post triage_bullet_accept_path(bullet), as: :turbo_stream

      assert_response :success
      assert_equal @daylog.id, bullet.reload.bucket_id
      assert_equal Date.current, bullet.pops_on
      assert bullet.rescheduled_migration?
    end

    test 'create is a no-op when bullet is already in the daylog' do
      daylog_bullet = create_bullet!(@user, bulletable: Note.new(body: 'Already today'))

      post triage_bullet_accept_path(daylog_bullet), as: :turbo_stream

      assert_response :success
      assert_equal @daylog.id, daylog_bullet.reload.bucket_id
    end
  end
end
