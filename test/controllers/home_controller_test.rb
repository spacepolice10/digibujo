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
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthly_bucket!(@user, name: 'june')
    @user.settings.update!(spreads_expanded: false)

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

  test 'collapsing a section persists and is reflected on next page load' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthly_bucket!(@user, name: 'june')
    post home_collapse_section_path('projects')
    assert_response :ok
    assert_equal false, @user.reload.settings.projects_expanded?

    get home_path
    assert_response :success
    assert_select 'details.home--section[data-controller=section][open]', count: 3
  end

  test 'expanding a collapsed section persists and is reflected on next page load' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthly_bucket!(@user, name: 'june')
    @user.settings.update!(projects_expanded: false)

    post home_expand_section_path('projects')
    assert_response :ok
    assert_equal true, @user.reload.settings.projects_expanded?

    get home_path
    assert_response :success
    assert_select 'details.home--section[data-controller=section][open]', count: 4
  end
end
