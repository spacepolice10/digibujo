# frozen_string_literal: true

require 'test_helper'

class MonthlyBucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_future_bucket!(@user)
  end

  test 'current returns monthly bucket when one exists for calendar month' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')

    assert_equal monthly_bucket, MonthlyBucket.current(@user)
  end

  test 'current returns nil when user has no spreads' do
    assert_nil MonthlyBucket.current(@user)
  end

  test 'current returns spread for calendar month not most recently created' do
    current_month = create_monthly_bucket!(@user, name: 'june')
    next_month = MonthlyBucket.period_for(Date.current.beginning_of_month.next_month)
    later = @user.future_buckets.first.monthly_buckets.create!(
      user: @user,
      **next_month
    )
    @user.buckets.create!(bucketable: later, name: 'july')

    assert_equal current_month, MonthlyBucket.current(@user)
  end

  test 'rejects duplicate period_from for same user' do
    create_monthly_bucket!(@user, name: 'june')
    period = MonthlyBucket.default_period
    duplicate = @user.future_buckets.first.monthly_buckets.build(
      user: @user,
      period_from: period[:period_from],
      period_to: period[:period_to]
    )
    @user.buckets.build(bucketable: duplicate, name: 'june again')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:period_from], 'has already been taken'
  end

  test 'rejects period_from outside selectable range on create' do
    too_far = Date.current.beginning_of_month + 6.months
    monthly_bucket = @user.future_buckets.first.monthly_buckets.build(
      user: @user,
      **MonthlyBucket.period_for(too_far)
    )

    assert_not monthly_bucket.valid?
    assert_includes monthly_bucket.errors[:period_from], 'must be within the next six months'
  end

  test 'rejects period that does not cover full calendar month' do
    monthly_bucket = @user.future_buckets.first.monthly_buckets.build(
      user: @user,
      period_from: Date.new(2026, 6, 1),
      period_to: Date.new(2026, 6, 15)
    )

    assert_not monthly_bucket.valid?
    assert_includes monthly_bucket.errors[:period_to], 'must be the last day of the spread month'
  end

  test 'covers_date? is true for dates in the spread month' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    day = monthly_bucket.period_from + 10.days

    assert monthly_bucket.covers_date?(day)
    assert monthly_bucket.covers_date?(monthly_bucket.period_from)
    assert monthly_bucket.covers_date?(monthly_bucket.period_to)
  end

  test 'covers_date? is false for dates outside the spread month' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')

    assert_not monthly_bucket.covers_date?(monthly_bucket.period_from - 1.day)
    assert_not monthly_bucket.covers_date?(monthly_bucket.period_to + 1.day)
  end

  test 'period_for returns full calendar month boundaries' do
    period = MonthlyBucket.period_for(Date.new(2026, 6, 15))

    assert_equal Date.new(2026, 6, 1), period[:period_from]
    assert_equal Date.new(2026, 6, 30), period[:period_to]
  end

  test 'default_period returns current month boundaries' do
    period = MonthlyBucket.default_period

    assert_equal Date.current.beginning_of_month, period[:period_from]
    assert_equal Date.current.end_of_month, period[:period_to]
  end

  test 'period_days returns inclusive range' do
    monthly_bucket = create_monthly_bucket!(
      @user,
      name: 'june',
      period_from: Date.new(2026, 6, 1),
      period_to: Date.new(2026, 6, 30)
    )

    assert_equal Date.new(2026, 6, 1)..Date.new(2026, 6, 30), monthly_bucket.period_days
  end

end
