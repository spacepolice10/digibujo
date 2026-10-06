# frozen_string_literal: true

require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders the shortcut list without the old cards' do
    get search_path

    assert_response :success
    assert_heading 'Search', level: 1
    assert_select 'main article.search--navigation ul a', count: 4
    assert_select 'main article.search--navigation ul a[href=?]', attachments_path, text: 'Attachments'
    assert_select 'main article.search--navigation ul a[href=?]', archived_index_path, text: 'Archive'
    assert_select 'main article.search--navigation ul a[href=?]', collections_path, text: 'Collections'
    assert_select 'main article.search--navigation ul a[href=?]', bullets_path(from: Date.current + 1), text: 'Upcoming'
    assert_select 'main small', count: 0
    assert_select '#index-dock', count: 0
    assert_select 'input#index-query', count: 0
    assert_select 'main header', count: 0
    assert_select 'main h2', count: 0
    assert_no_page_text 'Journal'
    assert_no_page_text 'Recently shared'
    assert_select 'details', count: 0
  end

  test 'desktop search shows the three item tabbar' do
    get search_path

    assert_response :success
    assert_select 'header.header', count: 0
    assert_select 'footer#footer', count: 0
    assert_tabbar_link search_path, label: 'Search', active: true
    assert_tabbar_link bullets_path, label: 'Daylog'
    assert_tabbar_link user_path, label: 'User'
    assert_select 'nav.tabbar--navigation a.tabbar--item', count: 2
    assert_select 'nav.tabbar--navigation span.tabbar--item-active[aria-current=page]', count: 1
    assert_select 'nav.tabbar--navigation a[href=?]', search_path, count: 0
    assert_select 'nav.tabbar--navigation a[href=?][data-hotkey=?][data-controller~=hotkey]', bullets_path, '2'
    assert_select 'nav.tabbar--navigation a[href=?][data-hotkey=?][data-controller~=hotkey]', user_path, '3'
  end

  test 'desktop daylog shows the tabbar' do
    get bullets_path

    assert_response :success
    assert_select 'nav.tabbar--navigation a.tabbar--item', count: 2
    assert_select 'nav.tabbar--navigation span.tabbar--item-active[aria-current=page]', text: 'Daylog'
    assert_select 'nav.tabbar--navigation a[href=?]', bullets_path, count: 0
    assert_select '#header_palette', count: 0
    assert_select 'header.header', count: 0
  end

  test 'header palette is gone' do
    get search_path

    assert_response :success
    assert_select '#header_palette', count: 0
  end

  # TODO: the collections tag grid is still specified in
  # docs/superpowers/specs/2026-10-01-unified-search-page-design.md but its loop
  # is commented out in app/views/searches/_navigation.html.erb. Restore the grid
  # and re-add per-collection coverage here.
  test 'show renders an empty collections grid container' do
    get search_path

    assert_response :success
    assert_select 'ul#search_collections[data-layout=grid]'
    assert_select 'ul#search_collections a', count: 0
  end

  test 'mobile show has no page header and a three item tabbar' do
    get search_path, headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_heading 'Search', level: 1
    assert_select 'main header', count: 0
    assert_select 'header.header', count: 0
    assert_select 'main article.search--navigation ul a[href=?]', bullets_path, count: 0
    assert_tabbar_link search_path, label: 'Search', active: true
    assert_tabbar_link bullets_path, label: 'Daylog'
    assert_tabbar_link user_path, label: 'User'
    assert_select 'nav.tabbar--navigation a.tabbar--item', count: 2
    assert_select 'nav.tabbar--navigation span.tabbar--item-active[aria-current=page]', count: 1
  end

  test 'show renders count badges when destinations have records' do
    create_bullet!(@user, body: 'Old note').archive!

    get search_path

    assert_response :success
    assert_select 'a[href=?] small', archived_index_path, text: '1'
    assert_select 'a[href=?] small', attachments_path, count: 0
  end

  test 'show works without a settings row and retains the selected appearance' do
    @user.create_settings! unless @user.settings
    @user.settings.update!(appearance: 'warm')

    get search_path
    assert_response :success
    assert_match 'data-appearance="warm"', response.body

    @user.settings.destroy!
    get search_path
    assert_response :success
  end
end
