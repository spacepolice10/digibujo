# frozen_string_literal: true

require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'
  SECTION_ORDER = %w[pins logs collections-attachments projects trackers recently-shared archive].freeze

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders the navigation hub in the intended order' do
    get home_path

    assert_response :success
    assert_equal SECTION_ORDER, rendered_section_order
    assert_link user_path, aria_label: 'Account'
    assert_select 'button[popovertarget="header_menu"]', text: /Digibujo/
    assert_select 'a', text: 'Monthly log', count: 1
    assert_link current_future_path, text: 'Future log'
    assert_select '.home--sections a[href=?]', daylog_path, count: 0
    assert_link published_index_path, text: 'Recently shared'
    assert_link archived_index_path, text: 'Archive'
    assert_select 'details', count: 0
  end

  test 'show renders empty sections and only the requested create links' do
    get home_path

    assert_response :success
    assert_link new_collection_path, text: 'Add collection'
    assert_link new_tracker_path, text: 'Add tracker'
    assert_select '.home--section-header .home--add-button', count: 0
    assert_select '.home--section-content .home--add-button, .home--split-section .home--add-button', count: 2
  end

  test 'show limits previews to three records' do
    4.times { |index| create_project!(@user, name: "project #{index}") }

    get home_path

    assert_response :success
    assert_select '[data-home-section="projects"] .home--section-content > .home--preview-link', count: 3
  end

  test 'mobile show uses the same hub and keeps the tabbar' do
    get home_path, headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_equal SECTION_ORDER, rendered_section_order
    assert_link search_path, text: 'Search'
    assert_link home_path, text: 'Digibujo'
    assert_select 'button[popovertarget="header_menu"]', count: 0
    assert_tabbar_link home_path, label: 'Menu'
    assert_tabbar_link daylog_path, label: 'Daily log'
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
    css_select('[data-home-section]').map { |node| node['data-home-section'] }
  end
end
