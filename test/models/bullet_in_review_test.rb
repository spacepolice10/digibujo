# frozen_string_literal: true

require 'test_helper'

class BulletInReviewTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @today = Date.current
  end

  test 'in_review includes timeline bullets in period' do
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Review me',
      pops_on: @today
    )

    assert_includes @user.bullets.in_review(from: @today, to: @today), bullet
  end

  test 'in_review excludes bucket members' do
    collection = create_collection!(@user, name: 'Inbox')
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Collected',
      pops_on: @today,
      bucket_id: collection.bucket.id
    )

    assert_not_includes @user.bullets.in_review(from: @today, to: @today), bullet
  end

  test 'in_review excludes archived bullets' do
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Archived',
      pops_on: @today
    )
    bullet.archive!

    assert_not_includes @user.bullets.in_review(from: @today, to: @today), bullet
  end

  test 'in_review excludes pops_on outside period' do
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Future',
      pops_on: @today + 3.days
    )

    assert_not_includes @user.bullets.in_review(from: @today, to: @today), bullet
  end

  test 'in_review excludes pops_on nil' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Unplanned', pops_on: nil)

    assert_not_includes @user.bullets.in_review(from: @today, to: @today), bullet
  end

  test 'in_review includes migrated bullets' do
    bullet = @user.bullets.create!(
      bulletable: Task.create!,
      body: 'Migrated',
      pops_on: @today
    )
    bullet.pop!(pops_on: @today + 1.day)
    bullet.update!(pops_on: @today)

    assert_includes @user.bullets.in_review(from: @today, to: @today), bullet
  end
end
