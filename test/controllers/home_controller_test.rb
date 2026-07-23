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
    assert_home_section 'Published'
    assert_page_text 'Public note'
    assert_no_page_text 'Private note'
    assert_section_index_link published_index_path, 'Published', count: 1
  end

  test 'show published section links to index when more than eight published bullets' do
    9.times do |index|
      bullet = create_bullet!(@user, bulletable: Note.new(body: "Published #{index}"))
      bullet.publish!
    end

    get home_path

    assert_response :success
    assert_section_index_link published_index_path, 'Published', count: 1
  end

  test 'show returns success' do
    get home_path
    assert_response :success
    assert_turbo_frame 'home_activities', src: home_activities_path
    assert_link user_path, aria_label: 'Account'
    assert_select 'footer span[aria-hidden=true]', text: @user.email_address.first.upcase
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
    assert_home_section 'Projects'
    assert_home_section 'Collections'
    assert_page_text 'alpha'
    assert_page_text 'reading'
    assert_section_index_link collections_path, 'Collections', count: 1
  end

  test 'show collections section links to index when more than eight collections' do
    9.times { |index| create_collection!(@user, name: "collection #{index}") }

    get home_path

    assert_response :success
    assert_section_index_link collections_path, 'Collections', count: 1
  end

  test 'show respects collapsed section preferences' do
    create_project!(@user, name: 'alpha')
    create_collection!(@user, name: 'reading')
    create_monthlylog!(@user, name: 'june')
    @user.settings.update!(projects_expanded: false)

    get home_path

    assert_response :success
    assert_home_sections total: 3, expanded: 2
    assert_home_section 'Projects', expanded: false
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
    assert_home_sections total: 3, expanded: 2
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
    assert_home_sections total: 3, expanded: 3
  end

  test 'show renders mobile home with expandable sections and create bucket' do
    create_project!(@user, name: 'mobile alpha')
    create_collection!(@user, name: 'mobile reading')

    get home_path, headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_select 'h1', text: /Hello #{Regexp.escape(@user.email_address)}/
    assert_form_action search_path
    assert_select '#home_create[popover]'
    assert_select '[popovertarget=?]', 'home_create'
    assert_select '.dropdown--element-header h2', text: 'Create'
    assert_menu_nav_link activities_path, label: 'Activity'
    assert_menu_nav_link review_path, label: 'Review'
    assert_menu_nav_link archived_index_path, label: 'Archived'
    assert_menu_nav_link published_index_path, label: 'Published'
    assert_menu_nav_link daylog_path, label: 'Daylog', count: 0
    assert_menu_nav_link home_path, label: 'Home', count: 0
    assert_tabbar_link home_path, label: 'Menu'
    assert_tabbar_link daylog_path, label: 'Daily log'
    assert_home_section 'Projects'
    assert_home_section 'Collections'
    assert_link new_collection_path, text: 'Add collection'
    assert_link user_path, aria_label: 'Account'
    assert_select 'span[aria-hidden=true]', text: @user.email_address.first.upcase
    assert_page_text 'mobile alpha'
  end

  test 'activity rail renders recent activities in home frame' do
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Rail visible'))
    activity = bullet.record_activity!('updated')

    get home_activities_path, headers: { 'Turbo-Frame' => 'home_activities' }

    assert_response :success
    assert_turbo_frame 'home_activities'
    assert_page_text 'Rail visible'
    assert_link bullet_path(bullet)
  end

  test 'activity rail shows empty state when there is no activity' do
    Activity.delete_all

    get home_activities_path, headers: { 'Turbo-Frame' => 'home_activities' }

    assert_response :success
    assert_page_text 'No recent activity'
  end
end
