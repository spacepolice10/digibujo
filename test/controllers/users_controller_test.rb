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
    assert_select 'a[href=?]', access_codes_path, text: /Access codes/
    assert_select 'a[href=?]', hooks_path, text: /Hooks/
    assert_select 'form[action=?][data-turbo-confirm=?]', authentication_path, 'Sign out of Digibujo?'
    assert_select 'button', text: /Sign out/
  end

  test 'show requires authentication' do
    sign_out

    get user_path

    assert_redirected_to new_authentication_path
  end
end
