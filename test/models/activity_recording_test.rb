# frozen_string_literal: true

require 'test_helper'

class ActivityRecordingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'complete records completed with migration metadata' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task', pops_on: Date.current)
    task = bullet.bulletable

    assert_difference -> { Activity.count }, 1 do
      task.complete!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'completed', activity.action
    assert_equal 'completed', activity.metadata['action']
    assert_equal bullet, activity.subject
    assert_equal @user.id, activity.user_id
  end

  test 'uncomplete records uncompleted' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task')
    task = bullet.bulletable
    task.complete!

    assert_difference -> { Activity.count }, 1 do
      task.uncomplete!
    end

    assert_equal 'uncompleted', Activity.order(:created_at).last.action
  end

  test 'archive records archived with migration metadata' do
    bullet = @user.bullets.create!(bulletable: Note.create!, body: 'Note', pops_on: Date.current)

    assert_difference -> { Activity.count }, 1 do
      bullet.archive!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'archived', activity.action
    assert_equal 'archived', activity.metadata['action']
  end

  test 'unarchive records unarchived activity' do
    bullet = @user.bullets.create!(bulletable: Note.create!, body: 'Note')
    bullet.archive!

    assert_difference -> { Activity.count }, 1 do
      bullet.unarchive!
    end

    assert_equal 'unarchived', Activity.order(:created_at).last.action
  end

  test 'collect records collected with migration metadata' do
    collection = create_collection!(@user, name: 'Inbox')
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Move')

    assert_difference -> { Activity.count }, 1 do
      bullet.collect!(bucket_id: collection.bucket.id)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'collected', activity.action
    assert_equal 'collected', activity.metadata['action']
    assert_equal collection.bucket.id, activity.metadata['bucket_id']
  end

  test 'mention project records project_mentioned' do
    project = create_project!(@user, name: 'Inbox')
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Move')

    assert_difference -> { Activity.count }, 1 do
      bullet.mentions.projects.add!(project_id: project.id)
    end

    assert_equal 'project_mentioned', Activity.order(:created_at).last.action
  end

  test 'pin toggle does not record activity' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Pin me')

    assert_no_difference -> { Activity.count } do
      bullet.pin!
      bullet.unpin!
    end
  end

  test 'pop records popped when moving to another day with migration metadata' do
    bullet = @user.bullets.create!(bulletable: Event.create!, body: 'Event', pops_on: Date.current)

    assert_difference -> { Activity.count }, 1 do
      bullet.pop!(pops_on: Date.current + 1)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'popped', activity.action
    assert_equal 'popped', activity.metadata['action']
  end

  test 'pop records popped' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Later')

    assert_difference -> { Activity.count }, 1 do
      bullet.pop!(pops_on: Date.current + 3)
    end

    assert_equal 'popped', Activity.order(:created_at).last.action
  end

  test 'direct update does not record activity' do
    bullet = @user.bullets.create!(bulletable: Note.create!, body: 'Before')

    assert_no_difference -> { Activity.count } do
      bullet.update!(body: 'After')
    end
  end

  test 'bucket update records updated activity' do
    collection = create_collection!(@user, name: 'before')

    assert_difference -> { Activity.count }, 1 do
      collection.bucket.update!(name: 'after')
    end

    activity = Activity.order(:created_at).last
    assert_equal 'updated', activity.action
  end
end
