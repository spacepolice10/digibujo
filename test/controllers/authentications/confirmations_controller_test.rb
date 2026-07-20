# frozen_string_literal: true

require 'test_helper'

module Authentications
  class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
    setup { @user = users(:one) }

    test 'new with login_email in session shows form' do
      request_login_code(@user.email_address)
      get new_authentication_confirmation_path

      assert_response :success
      assert_select 'header.header', count: 0
      assert_select '.session-layout--main form[action=?]', authentication_confirmation_path
    end

    test 'new without login_email redirects to authentication' do
      get new_authentication_confirmation_path

      assert_redirected_to new_authentication_path
    end

    test 'create with valid code for onboarded user starts session' do
      create_collection!(@user, name: Onboarding::LOOSE_NOTES_NAME)
      code = request_login_code(@user.email_address)
      confirm_login_code(code)

      assert_redirected_to root_path
      assert cookies[:session_id]
    end

    test 'create with valid lowercase code for onboarded user starts session' do
      create_collection!(@user, name: Onboarding::LOOSE_NOTES_NAME)
      code = request_login_code(@user.email_address)
      confirm_login_code(code.downcase)

      assert_redirected_to root_path
      assert cookies[:session_id]
    end

    test 'create with valid code for new user starts session and redirects to onboarding' do
      code = request_login_code(@user.email_address)
      confirm_login_code(code)

      assert_redirected_to new_onboarding_path
      assert cookies[:session_id]
    end

    test 'create with invalid code rejects' do
      request_login_code(@user.email_address)
      confirm_login_code('WRONG1')

      assert_redirected_to new_authentication_confirmation_path
      assert_nil cookies[:session_id]
    end

    test 'create with expired code rejects' do
      code = request_login_code(@user.email_address)
      @user.login_codes.last.update!(expires_at: 1.minute.ago)
      confirm_login_code(code)

      assert_redirected_to new_authentication_confirmation_path
      assert_nil cookies[:session_id]
    end

    test 'create destroys all user login codes on success' do
      code = request_login_code(@user.email_address)
      assert_equal 1, @user.login_codes.count

      confirm_login_code(code)

      assert_equal 0, @user.login_codes.count
    end
  end
end
