# frozen_string_literal: true

require 'test_helper'

class MonthlylogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'covering finds monthly log for a date in its month' do
    monthlylog = create_monthlylog!(@user, name: 'current')
    day = monthlylog.period_from + 10.days

    assert_equal monthlylog, @user.monthlylogs.covering(day).take
    assert_nil @user.monthlylogs.covering(monthlylog.period_from - 1.day).take
    assert_nil @user.monthlylogs.covering(monthlylog.period_to + 1.day).take
  end

  test 'spread_days returns every day in the month' do
    monthlylog = create_monthlylog!(@user, name: 'current')

    assert_equal (monthlylog.period_from..monthlylog.period_to).to_a, monthlylog.spread_days
  end

  test 'finds monthly log for calendar month' do
    monthlylog = create_monthlylog!(@user, name: 'current')

    assert_equal monthlylog, @user.monthlylogs.find_by(period_from: Date.current.beginning_of_month)
  end

  test 'returns nil when user has no spreads for month' do
    assert_nil @user.monthlylogs.find_by(period_from: Date.current.beginning_of_month)
  end

  test 'rejects duplicate period_from for same user' do
    create_monthlylog!(@user, name: 'current')
    duplicate = Monthlylog.new(
      user: @user,
      period_from: Date.current.beginning_of_month
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:period_from], 'has already been taken'
  end

  test 'normalizes period_to to end of month' do
    start = Date.current.beginning_of_month.next_month
    monthlylog = @user.monthlylogs.create!(
      period_from: start,
      period_to: start + 14.days
    )

    assert_equal start.end_of_month, monthlylog.period_to
  end

  test 'does not create a daylog after create' do
    monthlylog = create_monthlylog!(@user, name: 'current')

    assert_nil @user.daylog
    assert_not_nil monthlylog.bucket
  end
end
