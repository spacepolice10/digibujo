# frozen_string_literal: true

require 'test_helper'

class ActivityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @bullet = create_bullet!(@user, bulletable: Task.new(body: 'Task'))
  end

  test 'sweep job deletes activities older than retention' do
    stale = @bullet.record_activity!('updated')
    stale.update_column(:created_at, (Activity::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Activity.count }, -1 do
      SweepActivityLogsJob.perform_now
    end
  end

  test 'sweep job keeps recent activities' do
    @bullet.record_activity!('updated')

    assert_no_difference -> { Activity.count } do
      SweepActivityLogsJob.perform_now
    end
  end
end
