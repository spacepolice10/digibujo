# frozen_string_literal: true

require 'test_helper'

class ActivityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'detail describes popped migration' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Move', pops_on: Date.current)
    bullet.pop!(pops_on: Date.current + 1)

    activity = Activity.order(:created_at).last

    assert_includes activity.detail, 'Rescheduled from'
    assert_includes activity.detail, 'to'
  end

  test 'detail describes collected migration' do
    collection = create_collection!(@user, name: 'Inbox')
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Move')
    bullet.collect!(bucket_id: collection.bucket.id)

    activity = Activity.order(:created_at).last

    assert_equal "Moved into #{collection.name}", activity.detail
  end

  test 'detail is nil for bare updated activity' do
    bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Edit')
    bullet.record_activity!('updated')

    assert_nil Activity.order(:created_at).last.detail
  end

  test 'day_heading_for labels recent dates' do
    assert_equal 'Today', Activity.day_heading_for(Date.current)
    assert_equal 'Yesterday', Activity.day_heading_for(Date.yesterday)
  end
end
