# frozen_string_literal: true

require 'test_helper'

class SignupsControllerTest < ActionDispatch::IntegrationTest
  test 'new renders signup form' do
    get new_signup_path

    assert_response :success
    assert_select '.session-layout--main form[action=?]', signup_path
  end

  test 'create sends code and redirects to code page' do
    assert_difference 'User.count', 1 do
      assert_enqueued_emails 1 do
        post signup_path, params: { email_address: 'signup@example.com' }
      end
    end

    assert_redirected_to new_session_code_path
    assert_equal 'signup@example.com', session[:login_email]
    assert_equal 'signup', session[:auth_flow]
  end

  test 'create with invalid email rerenders form' do
    assert_no_difference 'User.count' do
      post signup_path, params: { email_address: 'nope' }
    end

    assert_response :unprocessable_entity
    assert_select 'form[action=?]', signup_path
  end
end
