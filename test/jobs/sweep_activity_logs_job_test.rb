# frozen_string_literal: true

require 'test_helper'

class SweepActivityLogsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @bullet = @user.bullets.create!(bulletable: Task.new(body: 'Task'))
  end

  test 'perform sweeps expired activities' do
    stale = @bullet.record_activity!('updated')
    stale.update_column(:created_at, (Activity::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Activity.count }, -1 do
      SweepActivityLogsJob.perform_now
    end
  end
end
