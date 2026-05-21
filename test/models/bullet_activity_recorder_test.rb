# frozen_string_literal: true

require "test_helper"

class BulletActivityRecorderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "complete records completed" do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: "Task")
    task = bullet.bulletable

    assert_difference -> { BulletActivity.count }, 1 do
      task.complete!
    end

    activity = BulletActivity.order(:created_at).last
    assert_equal 'completed', activity.action
    assert_equal bullet.id, activity.bullet_id
    assert_equal @user.id, activity.user_id
  end

  test "uncomplete records uncompleted" do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: "Task")
    task = bullet.bulletable
    task.complete!

    assert_difference -> { BulletActivity.count }, 1 do
      task.uncomplete!
    end

    assert_equal 'uncompleted', BulletActivity.order(:created_at).last.action
  end

  test "archive records archived" do
    bullet = @user.bullets.create!(bulletable: Note.create!, content: "Note")

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.archive!
    end

    assert_equal 'archived', BulletActivity.order(:created_at).last.action
  end

  test "unarchive does not record activity" do
    bullet = @user.bullets.create!(bulletable: Note.create!, content: "Note")
    bullet.archive!

    assert_no_difference -> { BulletActivity.count } do
      bullet.unarchive!
    end
  end

  test "collect records collected" do
    project = create_project!(@user, name: "Inbox")
    bullet = @user.bullets.create!(bulletable: Task.create!, content: "Move")

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.collect!(bucket_id: project.bucket.id)
    end

    assert_equal 'collected', BulletActivity.order(:created_at).last.action
  end

  test "pin toggle does not record activity" do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: "Pin me")

    assert_no_difference -> { BulletActivity.count } do
      bullet.update!(pinned: true)
      bullet.update!(pinned: false)
    end
  end

  test "postpone records postponed" do
    bullet = @user.bullets.create!(bulletable: Event.create!, content: "Event", pops_on: Date.current)

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.postpone_next_day!
    end

    assert_equal 'postponed', BulletActivity.order(:created_at).last.action
  end

  test "pop records popped" do
    bullet = @user.bullets.create!(bulletable: Task.create!, content: "Later")

    assert_difference -> { BulletActivity.count }, 1 do
      bullet.pop!(pops_on: Date.current + 3)
    end

    assert_equal "popped", BulletActivity.order(:created_at).last.action
  end

  test "direct update does not record activity" do
    bullet = @user.bullets.create!(bulletable: Note.create!, content: "Before")

    assert_no_difference -> { BulletActivity.count } do
      bullet.update!(content: "After", ends_date: Date.current + 3)
    end
  end
end
