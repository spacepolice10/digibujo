# frozen_string_literal: true

require 'test_helper'

class OnboardingTest < ActiveSupport::TestCase
  test 'complete provisions daylog, monthlylog and pending' do
    user = User.create!(email_address: 'onboarding-loose@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert user.reload.onboarded?
    assert_not user.futures.any?
    assert_not_nil user.monthlylogs.any?
    assert_equal 1, user.monthlylogs.count
    assert_not_nil user.daylog
    assert_not_nil user.daylog.bucket
    assert_equal Onboarding::DAYLOG_ICON, user.daylog.bucket.icon
    assert_not_nil user.pending
    assert_not_nil user.pending.bucket
    assert_equal Onboarding::PENDING_ICON, user.pending.bucket.icon
    assert_not user.buckets.exists?(bucketable_type: 'Collection')
    assert_equal 0, user.bullets.count
  end

  test 'complete is idempotent' do
    user = User.create!(email_address: 'onboarding-idempotent@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert onboarding.complete

    assert user.reload.onboarded?
    assert_equal 0, Future.where(user: user).count
    assert_equal 1, user.monthlylogs.count
    assert_equal 1, Daylog.where(user: user).count
    assert_equal 1, Pending.where(user: user).count
    assert_equal 1, user.buckets.where(bucketable_type: 'Daylog').count
    assert_equal 1, user.buckets.where(bucketable_type: 'Monthlylog').count
    assert_equal 1, user.buckets.where(bucketable_type: 'Pending').count
    assert_equal 0, user.buckets.where(bucketable_type: 'Collection').count
    assert_equal 0, user.bullets.count
  end

  test 'complete with data seed provisions sample data' do
    user = User.create!(email_address: 'onboarding-seed@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete
    assert user.reload.onboarded?
    assert_operator user.bullets.count, :>, 0
    assert user.bullets.where(bucket: user.daylog.bucket).any?
    assert user.bullets.where(bucket: user.monthlylogs.first.bucket).any?
    assert user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
    assert user.buckets.exists?(bucketable_type: 'Collection', name: 'reading list')
    assert user.buckets.exists?(bucketable_type: 'Future')
    assert_operator user.futures.count, :>=, 1
  end

  test 'complete with data seed is idempotent' do
    user = User.create!(email_address: 'onboarding-seed-idempotent@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete
    bullets_after_first = user.reload.bullets.count
    assert onboarding.complete

    assert_equal bullets_after_first, user.reload.bullets.count
  end

  test 'data_seed? normalizes string values' do
    assert Onboarding.new(user: User.new, data_seed: 'true').data_seed?
    assert Onboarding.new(user: User.new, data_seed: '1').data_seed?
    assert Onboarding.new(user: User.new, data_seed: true).data_seed?
    assert_not Onboarding.new(user: User.new, data_seed: 'false').data_seed?
    assert_not Onboarding.new(user: User.new, data_seed: nil).data_seed?
  end
end
