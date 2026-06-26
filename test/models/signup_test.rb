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

  test 'complete provisions future bucket and loose notes' do
    user = users(:one)
    signup = Signup.new(user: user)

    assert signup.complete
    assert user.buckets.exists?(bucketable_type: 'FutureBucket', name: 'future log')
    assert user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
  end

  test 'complete is idempotent' do
    user = users(:two)
    signup = Signup.new(user: user)

    assert signup.complete
    assert signup.complete

    assert_equal 1, FutureBucket.where(user: user).count
    assert_equal 1, user.buckets.where(bucketable_type: 'FutureBucket', name: 'future log').count
    assert_equal 1, user.buckets.where(bucketable_type: 'Collection', name: 'loose notes').count
  end
end
