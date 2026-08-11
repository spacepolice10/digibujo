# frozen_string_literal: true

require 'test_helper'

module Triage
  class DiscardsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      ensure_daylog!(@user)
      @pending = Pending.provision!(@user)
      @bullet = create_bullet!(
        @user,
        bucket: @pending.bucket,
        bulletable: Note.new, body: 'Throw away',
        pops_on: nil
      )
    end

    test 'create archives pending bullet and removes it from the inbox' do
      assert_difference -> { @user.bullets.active.count }, -1 do
        post triage_bullet_discard_path(@bullet), as: :turbo_stream
      end

      assert_response :success
      assert @bullet.reload.archived?
      assert_match %(turbo-stream action="remove" target="#{ActionView::RecordIdentifier.dom_id(@bullet, :triage)}"),
                   response.body
      assert_match 'Discarded', response.body
    end
  end
end
