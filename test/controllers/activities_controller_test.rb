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
end
