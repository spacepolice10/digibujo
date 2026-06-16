# frozen_string_literal: true

require 'test_helper'

class DaylogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'daylog without date shows today' do
    card = @user.bullets.create!(bulletable: Task.create!, body: 'Today card', pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_match card.body.to_plain_text, response.body
  end

  test 'daylog with year month day shows that day' do
    selected_date = Date.current - 2.days
    travel_to selected_date.in_time_zone.change(hour: 10) do
      @user.bullets.create!(bulletable: Task.create!, body: 'That day', pops_on: selected_date)
    end
    @user.bullets.create!(bulletable: Task.create!, body: 'Today noise', pops_on: Date.current)

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_match 'That day', response.body
    assert_no_match 'Today noise', response.body
  end

  test 'invalid calendar date returns not found' do
    get daylog_path(date: "#{Date.current.year}-02-30")

    assert_response :not_found
  end

  test 'daylog renders date navigation links' do
    selected_date = Date.current - 2.days

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_select "a[href='#{daylog_path(date: (selected_date - 1.day).iso8601)}']"
    assert_select "a[href='#{daylog_path(date: (selected_date + 1.day).iso8601)}']"
  end

  test 'daylog scopes bulk menu controls to the bullets list' do
    @user.bullets.create!(bulletable: Task.create!, body: 'Selectable card', pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_select '[data-controller~=?]', 'bullets-bulk', 0
    assert_select '[data-controller~=?]', 'bulk-menu' do
      assert_select '#bullets[data-bulk-menu-target=?]', 'list'
      assert_select '.bulk-menu[data-bulk-menu-target=?]', 'menu'
      assert_select 'input[type=checkbox][data-bulk-menu-target=?]', 'checkbox'
    end
  end

  test 'daylog renders composer with add bullet link and selected day as attribute' do
    selected_date = Date.current - 2.days

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_select 'turbo-frame#bullet_composer' do
      assert_select 'a[href=?]', new_bullet_path(pops_on: selected_date.iso8601)
      assert_match(/Add bullet/, response.body)
    end
  end

  test 'root shows today daylog' do
    card = @user.bullets.create!(bulletable: Task.create!, body: 'Root today', pops_on: Date.current)

    get root_path

    assert_response :success
    assert_match card.body.to_plain_text, response.body
  end

  test 'desktop daylog renders digibujo menu in header' do
    get daylog_path

    assert_response :success
    assert_select 'header.header details.dropdown.header--menu' do
      assert_select 'summary.header--summary', text: 'Digibujo'
      assert_select 'form.search--form[action=?]', search_path
      assert_select 'turbo-frame#menu_search'
    end
  end

  test 'mobile daylog omits header and renders tab bar' do
    get daylog_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select 'header.header', count: 0
    assert_select 'nav.tab-bar a[href=?]', menu_path
    assert_select 'nav.tab-bar a[href=?]', daylog_path
    assert_select 'nav.tab-bar a[href=?]', pinned_index_path
  end
end
