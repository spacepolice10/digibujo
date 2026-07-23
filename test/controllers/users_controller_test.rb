# frozen_string_literal: true

require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders account page with sign out' do
    get user_path

    assert_response :success
    assert_heading 'Account', level: 1
    assert_page_text @user.email_address
    assert_select 'form[action=?][data-turbo-confirm=?]', authentication_path, 'Sign out of Digibujo?'
    assert_select 'button', text: /Sign out/
  end

  test 'show requires authentication' do
    sign_out

    get user_path

    assert_redirected_to new_authentication_path
  end
end
