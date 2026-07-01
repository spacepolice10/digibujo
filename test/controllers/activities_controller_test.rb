# frozen_string_literal: true

require 'test_helper'

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index shows activities newest first' do
    a = @user.bullets.create!(bulletable: Task.create!, body: 'One')
    b = @user.bullets.create!(bulletable: Note.create!, body: 'Two')
    a.record_activity!('updated')
    b.record_activity!('archived', metadata: { 'action' => 'archived' })

    get activities_path

    assert_response :success
    assert_match 'Archived', response.body
    assert_match 'Updated', response.body
    assert_select '.activity--feed-item', minimum: 2
    assert_select '.layout--surface'
    assert_select '.activity--day-heading'
    assert_no_match 'layout--workspace', response.body
  end

  test 'index filters by subject' do
    keep = @user.bullets.create!(bulletable: Task.create!, body: 'Keep me visible')
    other = @user.bullets.create!(bulletable: Note.create!, body: 'Hidden from filter qxz')
    keep.record_activity!('completed', metadata: { 'action' => 'completed' })
    other.record_activity!('updated')

    get activities_path(subject_type: 'Bullet', subject_id: keep.id)

    assert_response :success
    assert_match 'Keep me visible', response.body
    assert_no_match 'Hidden from filter qxz', response.body
    assert_select '.activity--header-subtitle', text: 'Activity history'
  end

  test 'index returns not found for another users bullet' do
    other = users(:two)
    foreign = other.bullets.create!(bulletable: Task.create!, body: 'Foreign')

    get activities_path(subject_type: 'Bullet', subject_id: foreign.id)

    assert_response :not_found
  end

  test 'index returns not found for unknown subject type' do
    get activities_path(subject_type: 'Project', subject_id: 1)

    assert_response :not_found
  end

  test 'index shows empty state when there is no activity' do
    get activities_path

    assert_response :success
    assert_match 'No activity yet', response.body
  end

  test 'rail renders recent activities in home frame' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Rail visible')
    bullet.record_activity!('updated')

    get rail_activities_path, headers: { 'Turbo-Frame' => 'home_activity' }

    assert_response :success
    assert_select 'turbo-frame#home_activity'
    assert_match 'Rail visible', response.body
    assert_select '.activity--rail-item'
  end

  test 'rail shows empty state when there is no activity' do
    get rail_activities_path, headers: { 'Turbo-Frame' => 'home_activity' }

    assert_response :success
    assert_match 'No recent activity', response.body
  end
end
