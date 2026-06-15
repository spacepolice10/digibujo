# frozen_string_literal: true

class PeriodableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @monthly_bucket = MonthlyBucket.create!(
      user: @user,
      period_from: Date.new(2026, 6, 1),
      period_to: Date.new(2026, 6, 30)
    )
    @user.buckets.create!(
      bucketable: @monthly_bucket,
      name: 'june'
    )
  end

  test 'default_period returns current month boundaries' do
    period = MonthlyBucket.default_period

    assert_equal Date.current.beginning_of_month, period[:period_from]
    assert_equal Date.current.end_of_month, period[:period_to]
  end

  test 'period_days returns inclusive range' do
    assert_equal Date.new(2026, 6, 1)..Date.new(2026, 6, 30), @monthly_bucket.period_days
  end

  test 'period_ranges_correct rejects to before from' do
    @monthly_bucket.period_from = Date.new(2026, 6, 15)
    @monthly_bucket.period_to = Date.new(2026, 5, 15)

    assert_not @monthly_bucket.valid?
    assert_includes @monthly_bucket.errors[:period_to], 'must be on or after From'
  end

  test 'period_ranges_correct requires both or neither' do
    @monthly_bucket.period_from = Date.new(2026, 6, 1)
    @monthly_bucket.period_to = nil

    assert_not @monthly_bucket.valid?
    assert_includes @monthly_bucket.errors[:base], 'From and To must both be set or both be blank'
  end
end
