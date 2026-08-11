# frozen_string_literal: true

require 'test_helper'

class Monthlylogs::BulletsControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'

  setup do
    @user = users(:one)
    sign_in_as @user
    @monthlylog = create_monthlylog!(@user, name: 'june')
  end

  test 'dated index lists planned bullets without create buttons' do
    day = Date.current.beginning_of_month + 2.days
    create_bullet!(@user,
      bulletable: Task.new, body: 'Planned task',
      bucket_id: @monthlylog.bucket.id,
      pops_on: day
    )
    container = "date_#{day.iso8601}_bullets_container"

    get monthlylog_bullets_path(@monthlylog, date: day.iso8601)

    assert_response :success
    assert_match 'Planned task', response.body
    assert_select 'turbo-frame#monthlylog_date'
    assert_select "##{container}"
    assert_select 'a.bullets-form--create-button--task', count: 0
    assert_select "a[href=?]", daylog_path(date: day.iso8601)
  end

  test 'unplanned index lists unplanned bullets without create buttons' do
    create_bullet!(@user,
      bulletable: Note.new, body: 'Unplanned note',
      bucket_id: @monthlylog.bucket.id
    )
    container = 'monthlylog_bullets_unplanned_container'

    get monthlylog_bullets_path(@monthlylog)

    assert_response :success
    assert_match 'Unplanned note', response.body
    assert_select 'turbo-frame#monthlylog_unplanned'
    assert_select "##{container}"
    assert_select 'a.bullets-form--create-button--note', count: 0
    assert_select 'a.bullets-form--create-button--task', count: 0
  end

  test 'unplanned bullets render as compact rows without metadata tags' do
    bullet = create_bullet!(@user,
      bulletable: Task.new, body: 'Pinned spread task',
      bucket_id: @monthlylog.bucket.id
    )
    PinnedEntity.create!(user: @user, pinnable: bullet)

    get monthlylog_bullets_path(@monthlylog)

    assert_response :success
    assert_select "turbo-frame##{dom_id(bullet)}.bullet", text: /Pinned spread task/
    assert_select "turbo-frame##{dom_id(bullet)}.bullet .bullet--marker", count: 1
    assert_select "turbo-frame##{dom_id(bullet)}.bullet .bullet--tags", count: 0
    assert_select "turbo-frame##{dom_id(bullet)}.bullet .bullet--metadata", count: 0
  end

  test 'mobile unplanned bullets render without drag' do
    create_bullet!(@user,
      bulletable: Task.new, body: 'Mobile spread task',
      bucket_id: @monthlylog.bucket.id
    )

    get monthlylog_bullets_path(@monthlylog), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_match 'Mobile spread task', response.body
    assert_select '.bullet[data-layout="spread"]', count: 0
    assert_select 'turbo-frame.bullet[draggable="true"]', count: 0
    assert_select '.bullet--marker', minimum: 1
  end

  test 'before returns older page of dated bullets' do
    day = Date.current.beginning_of_month + 1.day
    older = create_bullet!(@user,
      bulletable: Task.new, body: 'Older planned',
      bucket_id: @monthlylog.bucket.id,
      pops_on: day
    )
    older.update_columns(created_at: 2.days.ago)
    newer = create_bullet!(@user,
      bulletable: Task.new, body: 'Newer planned',
      bucket_id: @monthlylog.bucket.id,
      pops_on: day
    )
    newer.update_columns(created_at: 1.day.ago)

    get monthlylog_bullets_path(@monthlylog, date: day.iso8601, before: newer.id)

    assert_response :success
    assert_match 'Older planned', response.body
    assert_no_match 'Newer planned', response.body
  end

  test 'before returns no content when cursor missing' do
    day = Date.current.beginning_of_month

    get monthlylog_bullets_path(@monthlylog, date: day.iso8601, before: 0)

    assert_response :no_content
  end

  test 'invalid date returns not found' do
    get monthlylog_bullets_path(@monthlylog, date: 'not-a-date')

    assert_response :not_found
  end

  test 'dated index mounts bullets_container id without create buttons' do
    day = Date.current.beginning_of_month
    container = "date_#{day.iso8601}_bullets_container"

    get monthlylog_bullets_path(@monthlylog, date: day.iso8601)

    assert_response :success
    assert_select "##{container}"
    assert_select '.bullets-form--create', count: 0
    assert_select '.chat--scroller'
  end

  test 'unplanned index mounts unplanned_bullets_container' do
    container = 'monthlylog_bullets_unplanned_container'

    get monthlylog_bullets_path(@monthlylog)

    assert_response :success
    assert_select "##{container}"
    assert_select '.bullets-form--create', count: 0
  end

  test 'foreign monthlylog returns not found' do
    other = create_monthlylog!(users(:two), name: 'private')

    get monthlylog_bullets_path(other)

    assert_response :not_found
  end

  test 'dated pane mounts chat-scroll on the merged scroller without a trigger' do
    day = Date.current.beginning_of_month + 2.days
    create_bullet!(@user,
      bulletable: Task.new, body: 'Planned task',
      bucket_id: @monthlylog.bucket.id,
      pops_on: day
    )
    container = "date_#{day.iso8601}_bullets_container"

    get monthlylog_bullets_path(@monthlylog, date: day.iso8601)

    assert_response :success
    assert_select 'div[data-controller~="chat-scroll"]'
    assert_select "div##{container}.chat--scroller[data-chat-scroll-target='scroller']"
    assert_select 'div[data-chat-scroll-target=trigger]', count: 0
  end

  test 'unplanned pane mounts chat-scroll and renders a load-more trigger over one page' do
    Bullet::Pageable::PAGE_SIZE.times do |i|
      create_bullet!(@user,
        bulletable: Task.new, body: "Spread task #{i}",
        bucket_id: @monthlylog.bucket.id
      )
    end
    container = 'monthlylog_bullets_unplanned_container'

    get monthlylog_bullets_path(@monthlylog)

    assert_response :success
    assert_select "div##{container}.chat--scroller[data-chat-scroll-target='scroller']"
    assert_select '.chat--load-more-trigger[data-chat-scroll-target=trigger]', count: 1
  end
end
