# frozen_string_literal: true

require 'test_helper'

class MonthlyBucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_future_bucket!(@user)
  end

  test 'current returns monthly bucket when one exists' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')

    assert_equal monthly_bucket, MonthlyBucket.current(@user)
  end

  test 'current returns nil when user has no spreads' do
    assert_nil MonthlyBucket.current(@user)
  end

  test 'current returns most recently created spread' do
    period = MonthlyBucket.default_period
    older = @user.future_bucket.monthly_buckets.create!(
      user: @user,
      period_from: period[:period_from].prev_month,
      period_to: period[:period_to].prev_month.end_of_month
    )
    @user.buckets.create!(bucketable: older, name: 'last month')

    newer = create_monthly_bucket!(@user, name: 'june')

    assert_equal newer, MonthlyBucket.current(@user)
  end
end
