# frozen_string_literal: true

require "test_helper"

class SprintTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @sprint = create_sprint!(
      @user,
      name: "Kitchen",
      starts_on: Date.current,
      ends_on: Date.current + 6.days
    )
  end

  test "status is active within date range" do
    assert_equal :active, @sprint.status
    assert_equal 6, @sprint.days_remaining
  end

  test "status is upcoming before start date" do
    sprint = create_sprint!(
      @user,
      name: "Later",
      starts_on: Date.current + 3.days,
      ends_on: Date.current + 10.days
    )

    assert_equal :upcoming, sprint.status
    assert_equal 3, sprint.days_remaining
  end

  test "status is ended after end date" do
    sprint = create_sprint!(
      @user,
      name: "Past",
      starts_on: Date.current - 10.days,
      ends_on: Date.current - 1.day
    )

    assert_equal :ended, sprint.status
    assert_equal 0, sprint.days_remaining
  end

  test "validates ends_on is on or after starts_on" do
    sprint = Sprint.new(starts_on: Date.current, ends_on: Date.current - 1.day)
    sprint.build_bucket(user: @user, name: "invalid")

    assert_not sprint.valid?
    assert_includes sprint.errors[:ends_on], "must be on or after the start date"
  end

  test "task_progress counts completed tasks in bucket" do
    @user.bullets.create!(bulletable: Task.create!, body: "One", bucket_id: @sprint.bucket.id)
    @user.bullets.create!(bulletable: Task.create!(completed: true), body: "Two", bucket_id: @sprint.bucket.id)
    @user.bullets.create!(bulletable: Note.create!, body: "Note", bucket_id: @sprint.bucket.id)

    progress = @sprint.task_progress

    assert_equal 2, progress[:total]
    assert_equal 1, progress[:completed]
    assert_equal 50, progress[:percent]
  end
end
