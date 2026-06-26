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
    period = MonthlyBucket.default_period
    older = @user.future_bucket.monthly_buckets.create!(
      user: @user,
      period_from: period[:period_from].prev_month,
      period_to: period[:period_to].prev_month.end_of_month
    )
    @user.buckets.create!(bucketable: older, name: 'last month')

    current_month = create_monthly_bucket!(@user, name: 'june')

    assert_equal current_month, MonthlyBucket.current(@user)
  end

  test 'rejects duplicate period_from for same user' do
    create_monthly_bucket!(@user, name: 'june')
    period = MonthlyBucket.default_period
    duplicate = @user.future_bucket.monthly_buckets.build(
      user: @user,
      period_from: period[:period_from],
      period_to: period[:period_to]
    )
    @user.buckets.build(bucketable: duplicate, name: 'june again')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:period_from], 'has already been taken'
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

  test 'month= sets period_from and period_to for full calendar month' do
    monthly_bucket = @user.future_bucket.monthly_buckets.build(user: @user, month: Date.new(2026, 6, 15))
    monthly_bucket.validate

    assert_equal Date.new(2026, 6, 1), monthly_bucket.period_from
    assert_equal Date.new(2026, 6, 30), monthly_bucket.period_to
  end

  test 'rejects partial calendar month' do
    monthly_bucket = @user.future_bucket.monthly_buckets.build(
      user: @user,
      period_from: Date.new(2026, 6, 1),
      period_to: Date.new(2026, 6, 15)
    )
    @user.buckets.build(bucketable: monthly_bucket, name: 'partial june')

    assert_not monthly_bucket.valid?
    assert_includes monthly_bucket.errors[:base], 'Spread must cover a full calendar month'
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

  test 'period_ranges_correct rejects to before from' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    monthly_bucket.period_from = Date.new(2026, 6, 15)
    monthly_bucket.period_to = Date.new(2026, 5, 15)

    assert_not monthly_bucket.valid?
    assert_includes monthly_bucket.errors[:period_to], 'must be on or after From'
  end

  test 'period_ranges_correct requires both or neither' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')
    monthly_bucket.period_from = Date.new(2026, 6, 1)
    monthly_bucket.period_to = nil

    assert_not monthly_bucket.valid?
    assert_includes monthly_bucket.errors[:base], 'From and To must both be set or both be blank'
  end
end
