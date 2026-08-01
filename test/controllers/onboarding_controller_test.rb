# frozen_string_literal: true

require 'test_helper'

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test 'new redirects when not signed in' do
    get new_onboarding_path

    assert_redirected_to new_authentication_path
  end

  test 'new renders for signed-in user' do
    code = request_login_code(@user.email_address)
    confirm_login_code(code)

    get new_onboarding_path

    assert_response :success
    assert_select '.session--name', text: 'Welcome to Digibujo'
    assert_select '.session-layout--main form[action=?]', onboarding_path
    assert_select 'a.onboarding--external-link[href=?]', 'https://bulletjournal.com/'
  end

  test 'create provisions loose notes and daylog' do
    code = request_login_code(@user.email_address)
    confirm_login_code(code)

    post onboarding_path

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert @user.reload.onboarded?
    assert_not_nil @user.daylog
    assert @user.buckets.exists?(bucketable_type: 'Daylog')
    assert_not @user.buckets.exists?(bucketable_type: 'Future')
    assert_not @user.futures.any?
    assert_not @user.monthlylogs.any?
    assert @user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
  end
end

