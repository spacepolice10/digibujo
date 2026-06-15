# frozen_string_literal: true

require 'test_helper'

class BulletActivityRecorderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'complete records completed' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task')
    task = bullet.bulletable

    assert_difference -> { BulletActivity.count }, 1 do
      task.complete!
    end

    activity = BulletActivity.order(:created_at).last
    assert_equal 'completed', activity.action
    assert_equal bullet.id, activity.bullet_id
    assert_equal @user.id, activity.user_id
  end

  test 'uncomplete records uncompleted' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task')
    task = bullet.bulletable
    task.complete!

    assert_difference -> { BulletActivity.count }, 1 do
      task.uncomplete!
    end

    assert_equal 'uncompleted', BulletActivity.order(:created_at).last.action
  end

  test 'archive records archived' do
    bullet = @user.bullets.create!(bulletable: Note.create!, body: 'Note')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.archive!
    end

    assert_equal 'archived', BulletActivity.order(:created_at).last.action
  end

  test 'unarchive does not record activity' do
    bullet = @user.bullets.create!(bulletable: Note.create!, body: 'Note')
    bullet.archive!

    assert_no_difference -> { BulletActivity.count } do
      bullet.unarchive!
    end
  end

  test 'collect records collected' do
    collection = create_collection!(@user, name: 'Inbox')
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Move')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.collect!(bucket_id: collection.bucket.id)
    end

    assert_equal 'collected', BulletActivity.order(:created_at).last.action
  end

  test 'tag project records project_tagged' do
    project = create_project!(@user, name: 'Inbox')
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Move')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.tag_project!(project_id: project.id)
    end

    assert_equal 'project_tagged', BulletActivity.order(:created_at).last.action
  end

  test 'pin toggle does not record activity' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Pin me')

    assert_no_difference -> { BulletActivity.count } do
      bullet.pin!
      bullet.unpin!
    end
  end

  test 'pop records popped when moving to another day' do
    bullet = @user.bullets.create!(bulletable: Event.create!, body: 'Event', pops_on: Date.current)

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.pop!(pops_on: Date.current + 1)
    end

    assert_equal 'popped', BulletActivity.order(:created_at).last.action
  end

  test 'pop records popped' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Later')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.pop!(pops_on: Date.current + 3)
    end

    assert_equal 'popped', BulletActivity.order(:created_at).last.action
  end

  test 'direct update does not record activity' do
    bullet = @user.bullets.create!(bulletable: Note.create!, body: 'Before')

    assert_no_difference -> { BulletActivity.count } do
      bullet.update!(body: 'After', ends_date: Date.current + 3)
    end
  end
end
