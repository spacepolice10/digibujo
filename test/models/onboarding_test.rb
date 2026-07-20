# frozen_string_literal: true

require 'test_helper'

class OnboardingTest < ActiveSupport::TestCase
  test 'complete provisions loose notes only' do
    user = User.create!(email_address: 'onboarding-loose@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert_not user.futures.any?
    assert_not user.monthlylogs.any?
    assert_nil user.daylog
    assert user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
  end

  test 'complete is idempotent' do
    user = User.create!(email_address: 'onboarding-idempotent@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert onboarding.complete

    assert_equal 0, Future.where(user: user).count
    assert_equal 0, user.monthlylogs.count
    assert_equal 0, Daylog.where(user: user).count
    assert_equal 1, user.buckets.where(bucketable_type: 'Collection', name: 'loose notes').count
  end

  test 'ensure_daylog_bucket! creates a single daylog' do
    user = User.create!(email_address: 'onboarding-daylog@example.com')

    bucket = Onboarding.ensure_daylog_bucket!(user)
    again = Onboarding.ensure_daylog_bucket!(user, Date.current + 1.month)

    assert_equal bucket, again
    assert_equal 1, Daylog.where(user: user).count
    assert_equal Onboarding::DAYLOG_ICON, bucket.icon
  end
end
