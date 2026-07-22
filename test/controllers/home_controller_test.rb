# frozen_string_literal: true

require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"

  setup do
    @user = users(:one)
    @user.create_settings! unless @user.settings
    ensure_future!(@user)
    sign_in_as @user
  end

  test 'show lists published bullets in section' do
    published = create_bullet!(@user, bulletable: Note.new(body: 'Public note'))
    published.publish!
    create_bullet!(@user, bulletable: Note.new(body: 'Private note'))

    get home_path

    assert_response :success
    assert_select '.home--section-name', text: 'Published'
    assert_match 'Public note', response.body
    assert_no_match 'Private note', response.body
    assert_select 'a.home--section-more[href=?]', published_index_path, count: 0
  end

  test 'show published section links to index when more than eight published bullets' do
    9.times do |index|
      bullet = create_bullet!(@user, bulletable: Note.new(body: "Published #{index}"))
      bullet.publish!
    end

    get home_path

    assert_response :success
    assert_select 'a.home--section-more[href=?]', published_index_path, count: 1
  end

  test 'show returns success' do
    get home_path
    assert_response :success
    assert_select 'turbo-frame#home_activity[src=?]', compact_activities_path
    assert_select '.account--dock a.menu--account-button[href=?][aria-label=?]', user_path, 'Account'
    assert_select '.menu--account-initial', text: @user.email_address.first.upcase
  end

  test 'show renders saved appearance on html' do
    @user.settings.update!(appearance: 'warm')

    get home_path

    assert_response :success
    assert_match 'data-appearance="warm"', response.body
    assert_select 'input[name=appearance][value=warm][checked=checked]'
  end

  test 'show lists projects and collections' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthlylog!(@user, name: 'june')

    get home_path

    assert_response :success
    assert_select '.home--section-name', text: 'Projects'
    assert_select '.home--section-name', text: 'Collections'
    assert_match 'alpha', response.body
    assert_match 'reading', response.body
    assert_select 'a.home--section-more[href=?]', collections_path, count: 0
  end

  test 'show collections section links to index when more than eight collections' do
    9.times { |index| create_collection!(@user, name: "collection #{index}") }

    get home_path

    assert_response :success
    assert_select 'a.home--section-more[href=?]', collections_path, count: 1
  end

  test 'show respects collapsed section preferences' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthlylog!(@user, name: 'june')
    @user.settings.update!(projects_expanded: false)

    get home_path

    assert_response :success
    assert_select 'details.home--section[data-controller=section]', count: 3
    assert_select 'details.home--section[open]', count: 2
  end

  test 'show works when user has no settings row' do
    @user.settings.destroy!

    get home_path

    assert_response :success
  end

  test 'collapsing a section persists and is reflected on next page load' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthlylog!(@user, name: 'june')
    post home_collapse_section_path('projects')
    assert_response :ok
    assert_equal false, @user.reload.settings.projects_expanded?

    get home_path
    assert_response :success
    assert_select 'details.home--section[data-controller=section][open]', count: 2
  end

  test 'expanding a collapsed section persists and is reflected on next page load' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthlylog!(@user, name: 'june')
    @user.settings.update!(projects_expanded: false)

    post home_expand_section_path('projects')
    assert_response :ok
    assert_equal true, @user.reload.settings.projects_expanded?

    get home_path
    assert_response :success
    assert_select 'details.home--section[data-controller=section][open]', count: 3
  end

  test 'show renders mobile home with expandable sections and create bucket' do
    create_project!(@user, name: 'mobile alpha')
    create_collection!(@user, name: 'mobile reading')

    get home_path, headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_select '.menu--page.menu--page-mobile'
    assert_select '.search[data-combobox-path-value=?]', search_path
    assert_select 'button.search--dismiss[aria-label=?]', 'Close search'
    assert_select '.menu--create-bucket[data-controller=?]', 'dialog'
    assert_select 'nav.menu--navigation a[href=?]', activities_path
    assert_select 'nav.menu--navigation a[href=?]', review_path
    assert_select 'nav.menu--navigation a[href=?]', archived_index_path
    assert_select 'nav.menu--navigation a[href=?]', published_index_path
    assert_select 'nav.menu--navigation a[href=?]', daylog_path, count: 0
    assert_select 'nav.menu--navigation a[href=?]', home_path, count: 0
    assert_select 'details.home--section[data-controller=?]', 'home-section'
    assert_select 'details.home--section summary .home--section-name', text: 'Projects'
    assert_select 'details.home--section summary .home--section-name', text: 'Collections'
    assert_select '.menu--create-bucket-link[href=?]', new_collection_path
    assert_select 'a.menu--account-button[href=?][aria-label=?]', user_path, 'Account'
    assert_select '.menu--account-initial', text: @user.email_address.first.upcase
    assert_select '.account--dock', count: 0
    assert_match 'mobile alpha', response.body
  end
end
