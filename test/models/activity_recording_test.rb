# frozen_string_literal: true

require 'test_helper'

class ActivityRecordingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'complete records completed activity and leaves inbox' do
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Task', pops_on: Date.current)
    task = bullet.bulletable

    assert_difference -> { Activity.count }, 1 do
      task.complete!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'completed', activity.action
    assert_equal bullet, activity.subject
    assert_equal @user.id, activity.user_id
    assert bullet.reload.migrated?
    assert_equal({}, bullet.last_migration)
  end

  test 'uncomplete records uncompleted' do
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Task')
    task = bullet.bulletable
    task.complete!

    assert_difference -> { Activity.count }, 1 do
      task.uncomplete!
    end

    assert_equal 'uncompleted', Activity.order(:created_at).last.action
  end

  test 'archive records archived activity on Archive subject' do
    bullet = create_bullet!(@user, bulletable: Note.new, body: 'Note', pops_on: Date.current)

    assert_difference -> { Activity.count }, 1 do
      bullet.archive!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'archived', activity.action
    assert_equal 'Archive', activity.subject_type
    assert_equal bullet.archive, activity.subject
    assert_equal 'Note', activity.metadata['name']
    assert_not bullet.reload.migrated?
  end

  test 'unarchive records unarchived activity' do
    bullet = create_bullet!(@user, bulletable: Note.new, body: 'Note')
    bullet.archive!

    assert_difference -> { Activity.count }, 1 do
      bullet.unarchive!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'unarchived', activity.action
    assert_equal 'Archive', activity.subject_type
  end

  test 'collect records collected with migration metadata' do
    collection = create_collection!(@user, name: 'Inbox')
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Move')

    assert_difference -> { Activity.count }, 1 do
      bullet.collect!(bucket_id: collection.bucket.id)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'collected', activity.action
    assert_equal 'collected', activity.metadata['action']
    assert_equal collection.bucket.id, activity.metadata['bucket_id']
  end

  test 'postpone records rescheduled when moving to another day with migration metadata' do
    bullet = create_bullet!(@user, bulletable: Event.new, body: 'Event', pops_on: Date.current)
    daylog = ensure_daylog!(@user)

    assert_difference -> { Activity.count }, 1 do
      bullet.postpone!(bucket: daylog, pops_on: Date.current + 1)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'rescheduled', activity.action
    assert_equal 'rescheduled', activity.metadata['action']
  end

  test 'postpone records rescheduled' do
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Later')
    daylog = ensure_daylog!(@user)

    assert_difference -> { Activity.count }, 1 do
      bullet.postpone!(bucket: daylog, pops_on: Date.current + 3)
    end

    assert_equal 'rescheduled', Activity.order(:created_at).last.action
  end
end
