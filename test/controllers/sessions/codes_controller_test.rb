require "test_helper"

class Sessions::CodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @record, @code = LoginCode.create_for(@user)
  end

  test "new with login_email in session shows form" do
    post session_path, params: { email_address: @user.email_address }
    get new_session_code_path

    assert_response :success
  end

  test "new without login_email redirects to login" do
    get new_session_code_path

    assert_redirected_to new_session_path
  end

  test "create with valid code starts session" do
    post session_path, params: { email_address: @user.email_address }
    post session_code_path, params: { code: @code }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with valid lowercase code starts session" do
    post session_path, params: { email_address: @user.email_address }
    post session_code_path, params: { code: @code.downcase }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid code rejects" do
    post session_path, params: { email_address: @user.email_address }
    post session_code_path, params: { code: "WRONG1" }

    assert_redirected_to new_session_code_path
    assert_nil cookies[:session_id]
  end

  test "create with expired code rejects" do
    @record.update!(expires_at: 1.minute.ago)

    post session_path, params: { email_address: @user.email_address }
    post session_code_path, params: { code: @code }

    assert_redirected_to new_session_code_path
    assert_nil cookies[:session_id]
  end

  test "create destroys all user login codes on success" do
    LoginCode.create_for(@user)

    post session_path, params: { email_address: @user.email_address }
    post session_code_path, params: { code: @code }

    assert_equal 0, @user.login_codes.count
  end
end
