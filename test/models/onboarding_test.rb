# frozen_string_literal: true

require 'test_helper'

class OnboardingTest < ActiveSupport::TestCase
  test 'complete provisions future bucket, monthly spread, and loose notes' do
    user = users(:one)
    onboarding = Onboarding.new(user: user)
    period = MonthlyBucket.default_period

    assert onboarding.complete
    assert user.buckets.exists?(bucketable_type: 'FutureBucket', name: 'future log')
    assert user.monthly_buckets.exists?(period_from: period[:period_from])
    assert user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
    future_bucket = user.buckets.find_by!(bucketable_type: 'FutureBucket')
    monthly_bucket = user.buckets.find_by!(bucketable_type: 'MonthlyBucket')
    assert future_bucket.activities.exists?(action: 'created')
    assert monthly_bucket.activities.exists?(action: 'created')
  end

  test 'complete is idempotent' do
    user = users(:two)
    onboarding = Onboarding.new(user: user)
    period = MonthlyBucket.default_period

    assert onboarding.complete
    assert onboarding.complete

    assert_equal 1, FutureBucket.where(user: user).count
    assert_equal 1, user.buckets.where(bucketable_type: 'FutureBucket', name: 'future log').count
    assert_equal 1, user.monthly_buckets.where(period_from: period[:period_from]).count
    assert_equal 1, user.buckets.where(bucketable_type: 'Collection', name: 'loose notes').count
    assert_equal 3, user.activities.where(action: 'created').count
  end
end
