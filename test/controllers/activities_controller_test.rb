# frozen_string_literal: true

require 'test_helper'

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index shows activities newest first' do
    a = @user.bullets.create!(bulletable: Task.create!, content: 'One')
    b = @user.bullets.create!(bulletable: Note.create!, content: 'Two')
    BulletActivity.record(user: @user, bullet: a, action: 'updated')
    BulletActivity.record(user: @user, bullet: b, action: 'archived')

    get activities_path

    assert_response :success
    assert_match 'Archived', response.body
    assert_match 'Updated', response.body
  end

  test 'index filters by bullet_id' do
    keep = @user.bullets.create!(bulletable: Task.create!, content: 'Keep me visible')
    other = @user.bullets.create!(bulletable: Note.create!, content: 'Hidden from filter qxz')
    BulletActivity.record(user: @user, bullet: keep, action: 'completed')
    BulletActivity.record(user: @user, bullet: other, action: 'updated')

    get activities_path(bullet_id: keep.id)

    assert_response :success
    assert_match 'Keep me visible', response.body
    assert_no_match 'Hidden from filter qxz', response.body
  end

  test 'index returns not found for another users bullet' do
    other = users(:two)
    foreign = other.bullets.create!(bulletable: Task.create!, content: 'Foreign')

    get activities_path(bullet_id: foreign.id)

    assert_response :not_found
  end
end
