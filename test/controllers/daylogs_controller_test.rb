# frozen_string_literal: true

require 'test_helper'

class DaylogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
  end

  test 'daylog without daylog shows create form' do
    @user.daylog.bucket.destroy!
    @user.reload

    get daylog_path

    assert_response :success
    assert_match 'No daily log yet', response.body
    assert_select "form[action=?]", daylog_path
    assert_match 'Create daylog', response.body
  end

  test 'create provisions daylog and redirects' do
    @user.daylog.bucket.destroy!
    @user.reload

    assert_difference -> { Daylog.where(user: @user).count }, 1 do
      post daylog_path
    end

    assert_redirected_to daylog_path
    assert_not_nil @user.reload.daylog
  end

  test 'daylog without date shows today' do
    card = create_bullet!(@user, bulletable: Task.new(body: 'Today card'), pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_match card.name, response.body
  end

  test 'daylog with year month day shows that day' do
    selected_date = Date.current - 2.days
    travel_to selected_date.in_time_zone.change(hour: 10) do
      create_bullet!(@user, bulletable: Task.new(body: 'That day'), pops_on: selected_date)
    end
    create_bullet!(@user, bulletable: Task.new(body: 'Today noise'), pops_on: Date.current)

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
    assert_select "a[href='#{daylog_path(date: (selected_date - 1.day).iso8601)}']" \
      "[data-action*='keydown.shift+left@document->hotkey#click'][data-hotkey='←']"
    assert_select "a[href='#{daylog_path(date: (selected_date + 1.day).iso8601)}']" \
      "[data-action*='keydown.shift+right@document->hotkey#click'][data-hotkey='→']"
    assert_select "button[popovertarget='pinned_list'][data-action*='keydown.shift+p@document->hotkey#click'][data-hotkey='P']"
  end

  test 'daylog scopes bulk menu controls to the bullets list' do
    create_bullet!(@user, bulletable: Task.new(body: 'Selectable card'), pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_select '[data-controller~=?]', 'bullets-bulk', 0
    assert_select '[data-controller~=?]', 'bulk-menu' do
      assert_select '[data-bulk-menu-target=?]', 'list'
      assert_select '.bulk-menu[data-bulk-menu-target=?]', 'menu'
      assert_select 'input[type=checkbox][data-bulk-menu-target=?]', 'checkbox'
    end
  end

  test 'desktop daylog dock links navigate to full page composer' do
    selected_date = Date.current - 2.days
    bucket_id = @user.daylog.bucket.id

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_select 'dialog#daylog_composer', count: 0
    assert_select '.bullets-form--dock' do
      assert_select 'a[data-turbo-frame=?][href=?]',
                    '_top',
                    new_bullet_path(
                      pops_on: selected_date,
                      bucket_id: bucket_id,
                      bulletable_type: 'Task'
                    )
      assert_select 'a[data-turbo-frame=?][href=?]',
                    '_top',
                    new_bullet_path(
                      pops_on: selected_date,
                      bucket_id: bucket_id,
                      bulletable_type: 'Event'
                    )
      assert_select 'a[data-turbo-frame=?][href=?]',
                    '_top',
                    new_bullet_path(
                      pops_on: selected_date,
                      bucket_id: bucket_id,
                      bulletable_type: 'Note'
                    )
    end
    assert_no_match(/Add bullet/, response.body)
  end

  test 'mobile daylog dock links navigate to full page composer' do
    selected_date = Date.current - 2.days
    mobile_ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'
    bucket_id = @user.daylog.bucket.id

    get daylog_path(date: selected_date.iso8601), headers: { 'User-Agent' => mobile_ua }

    assert_response :success
    assert_select 'dialog#daylog_composer', count: 0
    assert_select 'a[data-turbo-frame=?][href=?]',
                  '_top',
                  new_bullet_path(
                    pops_on: selected_date,
                    bucket_id: bucket_id,
                    bulletable_type: 'Task'
                  )
  end

  test 'root path is home' do
    get root_path

    assert_response :success
  end

  test 'daylog shows today bullets' do
    card = create_bullet!(@user, bulletable: Task.new(body: 'Root today'), pops_on: Date.current)

    get daylog_path

    assert_response :success
    assert_match card.name, response.body
  end

  test 'desktop daylog renders digibujo menu in header' do
    get daylog_path

    assert_response :success
    assert_select 'header.header .header--menu' do
      assert_select 'button.button--accent[popovertarget=?]', 'header_menu', text: 'Digibujo'
      assert_select '#header_menu.dropdown-body[popover]'
      assert_select 'form.search--form[action=?]', search_path
      assert_select 'turbo-frame#menu_search'
    end
  end

  test 'mobile daylog omits header and renders tab bar' do
    get daylog_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }

    assert_response :success
    assert_select 'header.header', count: 0
    assert_select 'nav.tabbar--navigation a[href=?]', home_path
    assert_select 'nav.tabbar--navigation a[href=?]', daylog_path
    assert_select 'nav.tabbar--navigation a[href=?]', pinned_index_path
  end

  test 'daylog renders mixed bullet types on the same page' do
    selected_date = Date.current
    create_bullet!(@user, bulletable: Task.new(body: 'Task line'), pops_on: selected_date)
    create_bullet!(@user, bulletable: Note.new(body: 'Note line'), pops_on: selected_date)
    create_bullet!(@user, bulletable: Event.new(body: 'Event line'), pops_on: selected_date)

    get daylog_path(date: selected_date.iso8601)

    assert_response :success
    assert_match 'Task line', response.body
    assert_match 'Note line', response.body
    assert_match 'Event line', response.body
  end
end
