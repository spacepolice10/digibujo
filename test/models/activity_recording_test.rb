# frozen_string_literal: true

require 'test_helper'

class ActivityRecordingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'complete records completed activity' do
    bullet = create_bullet!(@user, body: 'Task', pops_on: Date.current)

    assert_difference -> { Activity.count }, 1 do
      bullet.complete!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'completed', activity.action
    assert_equal bullet, activity.subject
    assert_equal @user.id, activity.user_id
    assert bullet.reload.done?
  end

  test 'uncomplete records uncompleted' do
    bullet = create_bullet!(@user, body: 'Task')
    bullet.complete!

    assert_difference -> { Activity.count }, 1 do
      bullet.uncomplete!
    end

    assert_equal 'uncompleted', Activity.order(:created_at).last.action
    assert_not bullet.reload.done?
  end

  test 'archive records archived activity on Archive subject' do
    bullet = create_bullet!(@user, body: 'Note', pops_on: Date.current)

    assert_difference -> { Activity.count }, 1 do
      bullet.archive!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'archived', activity.action
    assert_equal 'Archive', activity.subject_type
    assert_equal bullet.archive, activity.subject
  end

  test 'unarchive records unarchived activity' do
    bullet = create_bullet!(@user, body: 'Note')
    bullet.archive!

    assert_difference -> { Activity.count }, 1 do
      bullet.unarchive!
    end

    activity = Activity.order(:created_at).last
    assert_equal 'unarchived', activity.action
    assert_equal 'Archive', activity.subject_type
  end

  test 'collect records collected with the destination collection' do
    collection = create_collection!(@user, name: 'Inbox')
    bullet = create_bullet!(@user, body: 'Move')

    assert_difference -> { Activity.count }, 1 do
      bullet.collect!(collection_id: collection.id)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'collected', activity.action
    assert_equal collection.id, activity.metadata['collection_id']
    assert_equal collection, activity.destination_collection
  end

  test 'postpone records rescheduled with the old and new day' do
    bullet = create_bullet!(@user, body: 'Later', pops_on: Date.current)

    assert_difference -> { Activity.count }, 1 do
      bullet.postpone!(pops_on: Date.current + 3)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'rescheduled', activity.action
    assert_equal Date.current, activity.from_date
    assert_equal Date.current + 3, activity.to_date
  end
end
