# frozen_string_literal: true

require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.create_settings! unless @user.settings
    sign_in_as @user
  end

  test 'show returns success' do
    get home_path
    assert_response :success
  end

  test 'show lists projects collections and monthly buckets' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthly_bucket!(@user, name: 'june')

    get home_path

    assert_response :success
    assert_select '.home--section-title', text: 'Projects'
    assert_select '.home--section-title', text: 'Collections'
    assert_select '.home--section-title', text: 'Spreads'
    assert_match 'alpha', response.body
    assert_match 'reading', response.body
    assert_match 'june', response.body
  end

  test 'show respects collapsed section preferences' do
    @user.settings.update!(projects_open: false)

    get home_path

    assert_response :success
    assert_select 'details.home--section[data-controller=section]', count: 4
    assert_select 'details.home--section[open]', count: 3
  end

  test 'show works when user has no settings row' do
    @user.settings.destroy!

    get home_path

    assert_response :success
  end
end
