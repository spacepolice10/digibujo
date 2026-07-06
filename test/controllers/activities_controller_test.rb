# frozen_string_literal: true

require 'test_helper'

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index shows activities newest first' do
    a = @user.bullets.create!(bulletable: Task.new(body: 'One'))
    b = @user.bullets.create!(bulletable: Note.new(body: 'Two'))
    a.record_activity!('updated')
    b.record_activity!('archived', metadata: { 'action' => 'archived' })

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

  test 'rail renders recent activities in home frame' do
    bullet = @user.bullets.create!(bulletable: Task.new(body: 'Rail visible'))
    bullet.record_activity!('updated')

    get compact_activities_path, headers: { 'Turbo-Frame' => 'home_activity' }

    assert_response :success
    assert_select 'turbo-frame#home_activity'
    assert_match 'Rail visible', response.body
    assert_select '.activity--feed-item'
  end

  test 'rail shows empty state when there is no activity' do
    get compact_activities_path, headers: { 'Turbo-Frame' => 'home_activity' }

    assert_response :success
    assert_match 'No recent activity', response.body
  end

  test 'show renders popped activity with daylog links and history' do
    bullet = @user.bullets.create!(bulletable: Task.new(body: 'Buy milk'), pops_on: Date.current)
    bullet.record_activity!('updated')
    bullet.pop!(pops_on: Date.current + 2.days)
    activity = Activity.order(:created_at).last

    get activity_path(activity)

    assert_response :success
    assert_match 'Buy milk', response.body
    assert_match 'Moved from', response.body
    assert_select 'a[href=?]', daylog_path(date: Date.current.iso8601)
    assert_select 'a[href=?]', daylog_path(date: (Date.current + 2.days).iso8601)
    assert_select '.activity--history-item', count: 1
    assert_match 'Updated', response.body
  end

  test 'show renders collected activity with bucket link' do
    collection = create_collection!(@user, name: 'Reading list')
    bullet = @user.bullets.create!(bulletable: Task.new(body: 'Read chapter'))
    bullet.collect!(bucket_id: collection.bucket.id)
    activity = Activity.order(:created_at).last

    get activity_path(activity)

    assert_response :success
    assert_match 'Moved into Reading list', response.body
    assert_select 'a[href=?]', bucket_path(collection.bucket)
  end

  test 'show returns not found for another users activity' do
    other = users(:two)
    bullet = other.bullets.create!(bulletable: Task.new(body: 'Private'))
    activity = bullet.record_activity!('updated')

    get activity_path(activity)

    assert_response :not_found
  end

  test 'show renders bucket subject activity' do
    collection = create_collection!(@user, name: 'Inbox')
    collection.bucket.record_activity!('updated')

    get activity_path(collection.bucket.activities.last)

    assert_response :success
    assert_match 'Inbox', response.body
    assert_no_select '.activity--history'
  end

  test 'index feed links to activity show' do
    bullet = @user.bullets.create!(bulletable: Task.new(body: 'Linked'))
    bullet.record_activity!('updated')
    activity = Activity.order(:created_at).last

    get activities_path

    assert_response :success
    assert_select "a.activity--feed-item[href=?]", activity_path(activity)
  end
end
