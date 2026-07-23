# frozen_string_literal: true

require 'test_helper'

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index shows activities newest first' do
    a = create_bullet!(@user, bulletable: Task.new(body: 'One'))
    b = create_bullet!(@user, bulletable: Note.new(body: 'Two'))
    a.record_activity!('updated')
    b.archive!

    get activities_path

    assert_response :success
    assert_match 'Archived', response.body
    assert_match 'Updated', response.body
    assert_select '.activity--feed-item', minimum: 2
    assert_select '.layout--surface'
    assert_select '.activity--date'
    assert_no_match 'layout--workspace', response.body
  end

  test 'index shows empty state when there is no activity' do
    get activities_path

    assert_response :success
    assert_match 'No activity yet', response.body
  end

  test 'show renders rescheduled activity with daylog links' do
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Buy milk'), pops_on: Date.current)
    bullet.postpone!(bucket: ensure_daylog!(@user), pops_on: Date.current + 2.days)
    activity = Activity.order(:created_at).last

    get activity_path(activity)

    assert_response :success
    assert_match 'Buy milk', response.body
    assert_match 'Moved', response.body
    assert_select 'a[href=?]', daylog_path(date: Date.current.iso8601)
    assert_select 'a[href=?]', daylog_path(date: (Date.current + 2.days).iso8601)
    assert_select '.activity--history', count: 0
  end

  test 'show renders collected activity with bucket link' do
    collection = create_collection!(@user, name: 'Reading list')
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Read chapter'))
    bullet.collect!(bucket_id: collection.bucket.id)
    activity = Activity.order(:created_at).last

    get activity_path(activity)

    assert_response :success
    assert_match 'Read chapter', response.body
    assert_match 'reading list', response.body
    assert_select 'a[href=?]', bucket_path(collection.bucket)
  end

  test 'show returns not found for another users activity' do
    other = users(:two)
    bullet = create_bullet!(other, bulletable: Task.new(body: 'Private'))
    activity = bullet.record_activity!('updated')

    get activity_path(activity)

    assert_response :not_found
  end

  test 'show renders bucket subject activity' do
    collection = create_collection!(@user, name: 'Inbox')
    collection.bucket.record_activity!('updated')

    get activity_path(collection.bucket.activities.last)

    assert_response :success
    assert_match 'Updated', response.body
    assert_match 'inbox', response.body
    assert_select '.activity--history', count: 0
  end

  test 'index feed links to activity show' do
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Linked'))
    bullet.record_activity!('updated')
    activity = Activity.order(:created_at).last

    get activities_path

    assert_response :success
    assert_select "a.activity--feed-item[href=?]", activity_path(activity)
  end
end
