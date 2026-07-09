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
    assert_select '.session--title', text: 'Account'
    assert_select '.session--description strong', text: @user.email_address
    assert_select 'form.user--sign-out-form[action=?][data-turbo-confirm=?]', authentication_path, 'Sign out of Digibujo?'
    assert_select 'button.form--submit', text: /Sign out/
  end

  test 'show requires authentication' do
    sign_out

    get user_path

    assert_redirected_to new_authentication_path
  end
end
