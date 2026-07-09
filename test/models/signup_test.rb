# frozen_string_literal: true

require 'test_helper'

class SignupTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test 'create_identity creates a user and sends code' do
    signup = Signup.new(email_address: 'new-signup@example.com')

    assert_difference 'User.count', 1 do
      assert_enqueued_jobs 1 do
        assert signup.create_identity
      end
    end

    assert_equal 'new-signup@example.com', signup.user.email_address
  end

  test 'create_identity is invalid with malformed email' do
    signup = Signup.new(email_address: 'invalid')

    assert_no_difference 'User.count' do
      assert_not signup.create_identity
    end
  end

  test 'complete provisions future bucket, monthly spread, and loose notes' do
    user = users(:one)
    signup = Signup.new(user: user)
    period = MonthlyBucket.default_period

    assert signup.complete
    assert user.buckets.exists?(bucketable_type: 'FutureBucket', name: 'future log')
    assert user.monthly_buckets.exists?(period_from: period[:period_from])
    assert user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
    assert user.activities.exists?
    assert_includes user.activities.pluck(:action), 'completed'
    assert_includes user.activities.pluck(:action), 'collected'
    assert_includes user.activities.pluck(:action), 'popped'
  end

  test 'complete is idempotent' do
    user = users(:two)
    signup = Signup.new(user: user)
    period = MonthlyBucket.default_period

    assert signup.complete
    assert signup.complete

    assert_equal 1, FutureBucket.where(user: user).count
    assert_equal 1, user.buckets.where(bucketable_type: 'FutureBucket', name: 'future log').count
    assert_equal 1, user.monthly_buckets.where(period_from: period[:period_from]).count
    assert_equal 1, user.buckets.where(bucketable_type: 'Collection', name: 'loose notes').count
    assert_equal 5, user.activities.count
  end
end
