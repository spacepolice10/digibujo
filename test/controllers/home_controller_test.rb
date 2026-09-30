# frozen_string_literal: true

require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'
  SECTION_ORDER = ['Journal', 'Collections', 'Attachments', 'Projects', 'Recently shared'].freeze

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders the navigation hub in the intended order' do
    get home_path

    assert_response :success
    assert_equal SECTION_ORDER, rendered_section_order
    assert_link user_path, aria_label: 'Account'
    assert_select 'button[popovertarget="header_menu"]', text: /Dotted/
    assert_link timeline_path, text: 'Timeline'
    assert_link upcoming_path, text: 'Upcoming'
    assert_link collections_path, text: 'Show all...'
    assert_link projects_path, text: 'Show all...'
    assert_link published_index_path, text: 'Show all...'
    assert_link archived_index_path, text: 'Archive'
    assert_select 'details', count: 0
  end

  test 'show renders empty sections and the collection create link' do
    get home_path

    assert_response :success
    assert_link new_collection_path
    assert_page_text 'Collections are like folders'
    assert_page_text 'Put a # in your bullet'
    assert_page_text 'Share your bullets with others'
  end

  test 'show limits previews to the most recent records' do
    4.times { |index| create_project!(@user, name: "project #{index}") }

    get home_path

    assert_response :success
    assert_select 'article', text: /Projects/ do
      assert_select 'main li', count: HomeController::PREVIEW_LIMIT
    end
  end

  test 'mobile show uses the same hub and keeps the tabbar' do
    get home_path, headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_equal SECTION_ORDER, rendered_section_order
    assert_link search_path, text: 'Search'
    assert_link home_path, text: 'Dotted'
    assert_select 'button[popovertarget="header_menu"]', count: 0
    assert_tabbar_link home_path, label: 'Menu'
    assert_tabbar_link timeline_path, label: 'Timeline'
    assert_tabbar_link upcoming_path, label: 'Upcoming'
    assert_tabbar_link activities_path, label: 'Activity'
  end

  test 'show works without a settings row and retains the selected appearance' do
    @user.create_settings! unless @user.settings
    @user.settings.update!(appearance: 'warm')

    get home_path
    assert_response :success
    assert_match 'data-appearance="warm"', response.body

    @user.settings.destroy!
    get home_path
    assert_response :success
  end

  private

  def rendered_section_order
    css_select('main.home--page article > header h2').map { |node| node.text.strip }
  end
end
