# frozen_string_literal: true

require 'test_helper'

module Daylogs
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
          bulletable: Note.new, body: 'Capture me',
          pops_on: nil
        )
      end

      test 'create moves pending bullet into today daylog' do
        assert_changes -> { @bullet.reload.bucket_id }, to: @daylog.id do
          assert_changes -> { @bullet.reload.pops_on }, to: Date.current do
            post daylog_triage_accept_path, params: { bullet_ids: @bullet.id }, as: :turbo_stream
          end
        end

        assert_response :success
        assert @bullet.reload.rescheduled_migration?
        assert_match 'Added to today', response.body
        triage_id = ActionView::RecordIdentifier.dom_id(@bullet, :triage)
        assert_match %(turbo-stream action="remove" target="#{triage_id}"), response.body
      end

      test 'create moves monthlylog today bullet into daylog' do
        monthlylog = create_monthlylog!(@user, name: 'This month')
        bullet = create_bullet!(
          @user,
          bucket: monthlylog.bucket,
          bulletable: Task.new, body: 'From monthly',
          pops_on: Date.current
        )

        post daylog_triage_accept_path, params: { bullet_ids: bullet.id }, as: :turbo_stream

        assert_response :success
        assert_equal @daylog.id, bullet.reload.bucket_id
        assert_equal Date.current, bullet.pops_on
        assert bullet.rescheduled_migration?
      end

      test 'create rejects a bullet that is not in triage' do
        daylog_bullet = create_bullet!(@user, bulletable: Note.new, body: 'Already today')

        post daylog_triage_accept_path, params: { bullet_ids: daylog_bullet.id }, as: :turbo_stream

        assert_response :not_found
        assert_equal @daylog.id, daylog_bullet.reload.bucket_id
      end

      test 'bulk create moves selected triage bullets into today' do
        second = create_bullet!(
          @user, bucket: @pending.bucket, bulletable: Task.new, body: 'Second capture', pops_on: nil
        )

        post daylog_triage_accept_path, params: { bullet_ids: "#{@bullet.id},#{second.id}" }, as: :turbo_stream

        assert_response :success
        assert_equal [@daylog.id], [@bullet.reload.bucket_id, second.reload.bucket_id].uniq
        assert_match '2 bullets added to today', response.body
      end
    end
  end
end
