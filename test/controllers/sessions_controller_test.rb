require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with known email sends code and redirects to code page" do
    post session_path, params: { email_address: @user.email_address }

    assert_redirected_to new_session_code_path
    assert_equal @user.email_address, session[:login_email]
    assert_enqueued_emails 1
  end

  test "create with new email creates user, sends code, and redirects" do
    assert_difference "User.count", 1 do
      post session_path, params: { email_address: "newuser@example.com" }
    end

    assert_redirected_to new_session_code_path
    assert_equal "newuser@example.com", session[:login_email]
    assert_enqueued_emails 1

  end

  test "create with invalid email does not create user, still redirects" do
    assert_no_difference "User.count" do
      post session_path, params: { email_address: "not-an-email" }
    end

    assert_redirected_to new_session_code_path
    assert_equal "not-an-email", session[:login_email]
    assert_enqueued_emails 0
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
