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
    assert_select '#session-dots', count: 0
    assert_select 'canvas.session-dots', count: 0
    assert_select '.onboarding--heading', text: 'Welcome to Digibujo'
    assert_select '.onboarding-section', count: 6
    assert_select '.onboarding-dots li', count: 6
    assert_select '.onboarding-demo', count: 0
    assert_select '.onboarding-welcome', count: 0
    assert_select 'button[data-action=?]', 'onboarding#next'
    assert_select 'button[data-action=?]', 'onboarding#jumpToLast'
    assert_select 'input[type=radio][name=?]', 'data_seed', count: 2
    assert_select 'a[href=?]', features_path
    assert_select 'a[href=?]', support_path
    assert_select '.session-layout--main form[action=?]', onboarding_path
  end

  test 'create provisions base buckets without seed' do
    code = request_login_code(@user.email_address)
    confirm_login_code(code)

    post onboarding_path, params: { data_seed: 'false' }

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert @user.reload.onboarded?
    assert_not_nil @user.daylog
    assert @user.buckets.exists?(bucketable_type: 'Daylog')
    assert @user.buckets.exists?(bucketable_type: 'Monthlylog')
    assert @user.buckets.exists?(bucketable_type: 'Pending')
    assert_not @user.buckets.exists?(bucketable_type: 'Future')
    assert_not @user.futures.any?
    assert_not @user.buckets.exists?(bucketable_type: 'Collection')
    assert_equal 0, @user.bullets.count
  end

  test 'create with data seed provisions sample data' do
    code = request_login_code(@user.email_address)
    confirm_login_code(code)

    post onboarding_path, params: { data_seed: 'true' }

    assert_redirected_to root_path
    assert @user.reload.onboarded?
    assert_equal 44, @user.bullets.count
    assert @user.buckets.exists?(bucketable_type: 'Daylog')
    assert @user.buckets.exists?(bucketable_type: 'Monthlylog')
    assert @user.buckets.exists?(bucketable_type: 'Pending')
    assert @user.buckets.exists?(bucketable_type: 'Future')
    assert @user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
    assert @user.buckets.exists?(bucketable_type: 'Collection', name: 'reading list')
    assert_equal 6, @user.buckets.where(bucketable_type: 'Collection').count
    assert @user.bullets.where(bucket: @user.daylog.bucket).any?
  end
end
