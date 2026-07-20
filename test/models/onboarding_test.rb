# frozen_string_literal: true

require 'test_helper'

class OnboardingTest < ActiveSupport::TestCase
  test 'complete provisions loose notes and daylog' do
    user = User.create!(email_address: 'onboarding-loose@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert_not user.futures.any?
    assert_not user.monthlylogs.any?
    assert_not_nil user.daylog
    assert_not_nil user.daylog.bucket
    assert_equal Onboarding::DAYLOG_ICON, user.daylog.bucket.icon
    assert user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
  end

  test 'complete is idempotent' do
    user = User.create!(email_address: 'onboarding-idempotent@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert onboarding.complete

    assert_equal 0, Future.where(user: user).count
    assert_equal 0, user.monthlylogs.count
    assert_equal 1, Daylog.where(user: user).count
    assert_equal 1, user.buckets.where(bucketable_type: 'Daylog').count
    assert_equal 1, user.buckets.where(bucketable_type: 'Collection', name: 'loose notes').count
  end
end
