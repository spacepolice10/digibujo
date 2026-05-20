# frozen_string_literal: true

require 'test_helper'

class TracksBulletActivityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'complete records completed' do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: 'Task')
    task = bullet.bulletable

    assert_difference -> { BulletActivity.count }, 1 do
      task.complete!
    end

    activity = BulletActivity.order(:created_at).last
    assert_equal BulletActivity::COMPLETED, activity.action
    assert_equal bullet.id, activity.bullet_id
    assert_equal @user.id, activity.user_id
  end

  test 'uncomplete records uncompleted' do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: 'Task')
    task = bullet.bulletable
    task.complete!

    assert_difference -> { BulletActivity.count }, 1 do
      task.uncomplete!
    end

    assert_equal BulletActivity::UNCOMPLETED, BulletActivity.order(:created_at).last.action
  end

  test 'archive records archived' do
    bullet = @user.bullets.create!(bulletable: Note.create!, content: 'Note')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.archive!
    end

    assert_equal BulletActivity::ARCHIVED, BulletActivity.order(:created_at).last.action
  end

  test 'unarchive does not record edited' do
    bullet = @user.bullets.create!(bulletable: Note.create!, content: 'Note')
    bullet.archive!

    assert_no_difference -> { BulletActivity.count } do
      bullet.unarchive!
    end
  end

  test 'collect does not record edited' do
    project = create_project!(@user, name: 'Inbox')
    bullet = @user.bullets.create!(bulletable: Task.create!, content: 'Move')

    assert_no_difference -> { BulletActivity.count } do
      bullet.collect!(bucket_id: project.bucket.id)
    end
  end

  test 'pin toggle does not record edited' do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: 'Pin me')

    assert_no_difference -> { BulletActivity.count } do
      bullet.update!(pinned: true)
      bullet.update!(pinned: false)
    end
  end

  test 'postpone does not record edited' do
    bullet = @user.bullets.create!(bulletable: Event.create!, content: 'Event', scheduled_on: Date.current)

    assert_no_difference -> { BulletActivity.count } do
      bullet.postpone!
    end
  end

  test 'changing ends_date records edited' do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: 'End')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.update!(ends_date: Date.current + 7)
    end

    assert_equal BulletActivity::EDITED, BulletActivity.order(:created_at).last.action
  end

  test 'content change records edited' do
    bullet = @user.bullets.create!(bulletable: Note.create!, content: 'Before')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.update!(content: 'After')
    end

    assert_equal BulletActivity::EDITED, BulletActivity.order(:created_at).last.action
  end

  test 'content and column change records edited once' do
    bullet = @user.bullets.create!(bulletable: Note.create!, content: 'Before')

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.update!(content: 'After', ends_date: Date.current + 3)
    end

    assert_equal BulletActivity::EDITED, BulletActivity.order(:created_at).last.action
  end
end
