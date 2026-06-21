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
    @user.bullets.create!(bulletable: Task.create!, body: 'Review me', pops_on: @today)
    create_collection!(@user, name: 'Work')

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_select '.review--collections'
    assert_select '.review--inbox'
    assert_select '.review--week'
    assert_select '.review--week-days'
    assert_select '[data-controller="pop-drop"]', minimum: 1
    assert_select '[data-controller="collect-drop"]', minimum: 1
    assert_select 'turbo-frame.bullet[draggable="true"]', minimum: 1
    assert_select '.review--row-actions', count: 0
  end

  test 'show desktop week strip lists scheduled bullets for each day' do
    week_start = @today + 2.days
    @user.bullets.create!(bulletable: Event.create!, body: 'Team standup', pops_on: week_start)
    @user.bullets.create!(bulletable: Task.create!, body: 'Inbox only', pops_on: @today)

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_match 'Team standup', response.body
    assert_select '.review--week-day-drop .bullet--monthly-bucket', text: /Team standup/
  end

  test 'show mobile renders inbox row actions without week strip' do
    @user.bullets.create!(bulletable: Task.create!, body: 'Mobile review', pops_on: @today)

    get review_path(from: @today.iso8601, to: @today.iso8601), headers: { 'User-Agent' => MOBILE_UA }

    assert_response :success
    assert_match 'Mobile review', response.body
    assert_select '.review--week', count: 0
    assert_select '.review--collections', count: 0
    assert_select '.review--row-actions', minimum: 1
    assert_select 'turbo-frame.bullet[draggable="true"]', count: 0
    assert_select '#review_collect_picker_frame'
  end

  test 'show defaults to the last seven days through today' do
    @user.bullets.create!(bulletable: Task.create!, body: 'Today task', pops_on: @today)
    @user.bullets.create!(bulletable: Note.create!, body: 'Earlier this week', pops_on: @today - 5.days)
    @user.bullets.create!(bulletable: Event.create!, body: 'Too old', pops_on: @today - 8.days)

    get review_path

    assert_response :success
    assert_match 'Today task', response.body
    assert_match 'Earlier this week', response.body
    assert_no_match 'Too old', response.body
  end

  test 'show requires authentication' do
    sign_out

    get review_path

    assert_redirected_to new_session_path
  end

  test 'show returns not found for invalid date' do
    get review_path(from: 'not-a-date')

    assert_response :not_found
  end

  test 'show includes archive all when inbox has bullets' do
    @user.bullets.create!(bulletable: Task.create!, body: 'To archive', pops_on: @today)

    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_select '#review-inbox-footer button', text: /Archive all/
  end

  test 'show hides archive all when inbox is empty' do
    get review_path(from: @today.iso8601, to: @today.iso8601)

    assert_response :success
    assert_select '#review-inbox-footer', count: 0
  end

  test 'archive all archives every in-review bullet for the period' do
    in_period = @user.bullets.create!(bulletable: Task.create!, body: 'In period', pops_on: @today)
    other_day = @user.bullets.create!(bulletable: Note.create!, body: 'Other day', pops_on: @today - 2.days)

    post archive_all_review_path(from: @today.iso8601, to: @today.iso8601)

    assert_redirected_to review_path(from: @today.iso8601, to: @today.iso8601)
    assert in_period.reload.archived?
    assert_not other_day.reload.archived?
  end

  test 'archive all responds with turbo stream' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Stream archive', pops_on: @today)

    post archive_all_review_path(from: @today.iso8601, to: @today.iso8601),
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert bullet.reload.archived?
    assert_match 'turbo-stream action="update" target="paginated-records"', response.body
    assert_match 'turbo-stream action="update" target="review-amount-in-review"', response.body
    assert_match 'turbo-stream action="remove" target="review-inbox-footer"', response.body
  end
end
