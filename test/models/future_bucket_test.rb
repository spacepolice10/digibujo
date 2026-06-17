# frozen_string_literal: true

require 'test_helper'

class FutureBucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_future_bucket!(@user)
  end

  test 'only one future bucket per user' do
    duplicate = FutureBucket.new(user: @user)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], 'has already been taken'
  end
end
