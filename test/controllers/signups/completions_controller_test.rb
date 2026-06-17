# frozen_string_literal: true

require 'test_helper'

module Signups
  class CompletionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
    end

    test 'new redirects when signup session is missing' do
      get new_signup_completion_path

      assert_redirected_to new_signup_path
    end

    test 'new renders when signup session is present' do
      post signup_path, params: { email_address: @user.email_address }
      _record, code = LoginCode.create_for(@user)
      post session_code_path, params: { code: code }

      get new_signup_completion_path

      assert_response :success
      assert_select '.session-layout--main form[action=?]', signup_completion_path
    end

    test 'create provisions defaults and starts session' do
      post signup_path, params: { email_address: @user.email_address }
      _record, code = LoginCode.create_for(@user)
      post session_code_path, params: { code: code }

      post signup_completion_path

      assert_redirected_to root_path
      assert cookies[:session_id]
      assert @user.buckets.exists?(bucketable_type: 'FutureBucket', name: 'future log')
      assert @user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
    end
  end
end
