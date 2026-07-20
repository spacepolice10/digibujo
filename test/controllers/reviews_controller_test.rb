# frozen_string_literal: true

require 'test_helper'

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'

  setup do
    @user = users(:one)
    sign_in_as @user
    @today = Date.current
  end

  test 'show lists timeline bullets in period' do
    in_review = create_bullet!(@user,
      bulletable: Task.new(body: 'Needs review'),
      pops_on: @today
    )
    collection = create_collection!(@user, name: 'Inbox')
    create_bullet!(@user,
      bulletable: Note.new(body: 'In bucket'),
      pops_on: nil,
      bucket_id: collection.bucket.id
    )

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_match 'Needs review', response.body
    assert_no_match 'In bucket', response.body
    assert_select '[data-bulk-menu-target="list"]'
  end

  test 'show desktop renders three-column workspace with lazy frames' do
    create_bullet!(@user, bulletable: Task.new(body: 'Review me'), pops_on: @today)
    create_collection!(@user, name: 'Work')

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_select 'turbo-frame#review_collections_frame[src=?]', review_collections_path(from: @today.iso8601, to: @today.iso8601)
    assert_select 'turbo-frame#review_scheduled_frame[src=?]', review_scheduled_path(from: @today.iso8601, to: @today.iso8601)
    assert_select '.review--to-review'
    assert_select '[data-bulk-menu-target="list"]'
    assert_select '.review--review-actions', count: 0
  end

  test 'show mobile renders inbox list with bulk menu' do
    create_bullet!(@user, bulletable: Task.new(body: 'Mobile review'), pops_on: @today)

    get review_path(from: @today.iso8601, to: @today.iso8601), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_match 'Mobile review', response.body
    assert_select '.review--to-review', count: 0
    assert_select '.review--to-review-list'
    assert_select '.review--review-actions', count: 0
    assert_select '.review--bullet[draggable="true"]'
    assert_select '[data-bulk-menu-target="list"]'

    assert_select '#collects_picker_dropdown_id[popover]'
  end

  test 'show defaults to the last seven days through today' do
    create_bullet!(@user, bulletable: Task.new(body: 'Today task'), pops_on: @today)
    create_bullet!(@user, bulletable: Note.new(body: 'Earlier this week'), pops_on: @today - 5.days)
    create_bullet!(@user, bulletable: Event.new(body: 'Too old'), pops_on: @today - 8.days)

    get review_path

    assert_response :success
    assert_match 'Today task', response.body
    assert_match 'Earlier this week', response.body
    assert_no_match 'Too old', response.body
  end

  test 'show excludes archived migrated and unplanned bullets from inbox' do
    create_bullet!(@user, bulletable: Task.new(body: 'In review'), pops_on: @today)
    archived = create_bullet!(@user, bulletable: Task.new(body: 'Archived'), pops_on: @today)
    archived.archive!
    migrated = create_bullet!(@user, bulletable: Task.new(body: 'Migrated'), pops_on: @today)
    migrated.postpone!(bucket: ensure_daylog!(@user), pops_on: @today + 1.day)
    migrated.update!(pops_on: @today)
    collection = create_collection!(@user, name: 'park')
    create_bullet!(@user,
      bulletable: Task.new(body: 'Unplanned'),
      bucket_id: collection.bucket.id,
      pops_on: nil
    )

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_select '.review--to-review', text: /In review/
    assert_select '.review--to-review', text: /Archived/, count: 0
    assert_select '.review--to-review', text: /Migrated/, count: 0
    assert_select '.review--to-review', text: /Unplanned/, count: 0
  end

  test 'show requires authentication' do
    sign_out

    get review_path

    assert_redirected_to new_authentication_path
  end

  test 'show renders empty state when nothing is in review' do
    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_select '.review--to-review-empty', text: 'Nothing to review'
    assert_select '#review-amount-in-review', text: '0'
  end

end
