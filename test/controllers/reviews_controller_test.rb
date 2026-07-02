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
    in_review = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Needs review',
      pops_on: @today
    )
    collection = create_collection!(@user, name: 'Inbox')
    @user.bullets.create!(
      bulletable: Note.create!,
      body: 'In bucket',
      pops_on: @today - 1.day,
      bucket_id: collection.bucket.id
    )

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_match 'Needs review', response.body
    assert_no_match 'In bucket', response.body
    assert_select '[data-bulk-menu-target="list"]'
  end

  test 'show desktop renders three-column workspace' do
    @user.bullets.create!(bulletable: Task.new(body: 'Review me'), pops_on: @today)
    create_collection!(@user, name: 'Work')

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_select '.review--collections'
    assert_select '.review--to-review'
    assert_select '.review--week'
    assert_select '.monthly-bucket--calendar-body'
    assert_select '.bulk-menu--collect-section'
    assert_select '.bulk-menu--collect-item-link', minimum: 1
    assert_select '[data-controller="pops-drop"]', minimum: 1
    assert_select '[data-controller="collect-drop"]', minimum: 1
    assert_select '.review--bullet[draggable="true"]', minimum: 1
    assert_select '.review--review-actions', count: 0
  end

  test 'show desktop week strip lists scheduled bullets for each day' do
    week_start = @today + 2.days
    @user.bullets.create!(bulletable: Event.new(body: 'Team standup'), pops_on: week_start)
    @user.bullets.create!(bulletable: Task.new(body: 'Inbox only'), pops_on: @today)

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_match 'Team standup', response.body
    assert_select '.monthly-bucket--date-entries .bullet--monthly-bucket', text: /Team standup/
  end

  test 'show mobile renders review actions without week strip' do
    @user.bullets.create!(bulletable: Task.new(body: 'Mobile review'), pops_on: @today)

    get review_path(from: @today.iso8601, to: @today.iso8601), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_match 'Mobile review', response.body
    assert_select '.review--week', count: 0
    assert_select '.review--collections', count: 0
    assert_select '.review--review-actions', minimum: 1
    assert_select '.review--bullet[draggable="true"]', count: 0
    assert_select '[data-action="bulk-menu#selectAndOpenCollects"]', minimum: 1
    assert_select '#collects_picker_dropdown_id[popover]'
  end

  test 'show defaults to the last seven days through today' do
    @user.bullets.create!(bulletable: Task.new(body: 'Today task'), pops_on: @today)
    @user.bullets.create!(bulletable: Note.new(body: 'Earlier this week'), pops_on: @today - 5.days)
    @user.bullets.create!(bulletable: Event.new(body: 'Too old'), pops_on: @today - 8.days)

    get review_path

    assert_response :success
    assert_match 'Today task', response.body
    assert_match 'Earlier this week', response.body
    assert_no_match 'Too old', response.body
  end

  test 'show excludes archived migrated and unplanned bullets from inbox' do
    @user.bullets.create!(bulletable: Task.new(body: 'In review'), pops_on: @today)
    archived = @user.bullets.create!(bulletable: Task.new(body: 'Archived'), pops_on: @today)
    archived.archive!
    migrated = @user.bullets.create!(bulletable: Task.new(body: 'Migrated'), pops_on: @today)
    migrated.pop!(pops_on: @today + 1.day)
    migrated.update!(pops_on: @today)
    @user.bullets.create!(bulletable: Task.new(body: 'Unplanned'), pops_on: nil)

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

    assert_redirected_to new_session_path
  end

  test 'migrate marks all bullets in review period' do
    in_review = @user.bullets.create!(bulletable: Task.new(body: 'Keep as is'), pops_on: @today)
    @user.bullets.create!(bulletable: Note.new(body: 'Already migrated'), pops_on: @today).tap(&:acknowledge_migration!)

    get review_path(from: @today.iso8601, to: @today.iso8601)
    assert_select '.review--to-review', text: /Keep as is/

    post migrate_review_path(from: @today.iso8601, to: @today.iso8601)

    assert_redirected_to review_path(from: @today.iso8601, to: @today.iso8601)
    assert in_review.reload.migrated?
    assert_equal 'acknowledged', in_review.last_migration['action']

    get review_path(from: @today.iso8601, to: @today.iso8601)
    assert_select '#review-amount-in-review', text: '0'
    assert_select '.review--to-review', text: /Keep as is/, count: 0
  end

  test 'migrate with bullet_ids marks only selected bullets' do
    first = @user.bullets.create!(bulletable: Task.new(body: 'First'), pops_on: @today)
    second = @user.bullets.create!(bulletable: Task.new(body: 'Second'), pops_on: @today)

    post migrate_review_path(from: @today.iso8601, to: @today.iso8601),
         params: { bullet_ids: first.id.to_s },
         as: :turbo_stream

    assert_response :success
    assert first.reload.migrated?
    assert_not second.reload.migrated?
  end

  test 'migrate requires authentication' do
    sign_out

    post migrate_review_path

    assert_redirected_to new_session_path
  end

end
