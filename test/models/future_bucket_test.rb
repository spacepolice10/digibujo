# frozen_string_literal: true

require 'test_helper'

class FutureBucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_future_bucket!(@user)
  end

  test 'allows multiple future buckets per user' do
    duplicate = FutureBucket.new(user: @user)

    assert duplicate.valid?
  end
end
