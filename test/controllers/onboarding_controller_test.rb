# frozen_string_literal: true

require 'test_helper'

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test 'new redirects when authenticated user session is missing' do
    get new_onboarding_path

    assert_redirected_to new_authentication_path
  end

  test 'new redirects when authenticated user session expired' do
    session[:authenticated_user_id] = @user.id
    session[:authenticated_user_at] = LoginCode::EXPIRY.ago.to_i

    get new_onboarding_path

    assert_redirected_to new_authentication_path
    assert_nil session[:authenticated_user_id]
  end

  test 'new renders when authenticated user session is present' do
    code = request_login_code(@user.email_address)
    confirm_login_code(code)

    get new_onboarding_path

    assert_response :success
    assert_select '.session--title', text: 'Welcome to Digibujo'
    assert_select '.session-layout--main form[action=?]', onboarding_path
    assert_select 'a.onboarding--external-link[href=?]', 'https://bulletjournal.com/'
  end

  test 'create provisions defaults and starts session' do
    code = request_login_code(@user.email_address)
    confirm_login_code(code)

    post onboarding_path

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert @user.buckets.exists?(bucketable_type: 'FutureBucket', name: 'future log')
    assert @user.monthly_buckets.exists?(period_from: MonthlyBucket.default_period[:period_from])
    assert @user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
  end
end
