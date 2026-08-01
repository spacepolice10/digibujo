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

  test 'provision! creates monthlylog and bucket for current month' do
    user = User.create!(email_address: 'monthlylog-provision@example.com')
    month = Date.current.beginning_of_month

    monthlylog = Monthlylog.provision!(user)

    assert_equal monthlylog, user.monthlylogs.covering(Date.current).take
    assert_equal month, monthlylog.period_from
    assert_equal month.end_of_month, monthlylog.period_to
    assert_not_nil monthlylog.bucket
    assert_equal month.strftime('%B %Y').downcase, monthlylog.bucket.name
    assert_equal 'calendar', monthlylog.bucket.icon
  end

  test 'provision! is idempotent when covering monthlylog already exists' do
    user = User.create!(email_address: 'monthlylog-idempotent@example.com')
    first = Monthlylog.provision!(user)

    assert_no_difference -> { Monthlylog.where(user: user).count } do
      assert_equal first, Monthlylog.provision!(user)
    end
  end

  test 'provision! attaches bucket when monthlylog exists without one' do
    user = User.create!(email_address: 'monthlylog-orphan@example.com')
    month = Date.current.beginning_of_month
    monthlylog = user.monthlylogs.create!(period_from: month)

    repaired = Monthlylog.provision!(user)

    assert_equal monthlylog, repaired
    assert_not_nil repaired.bucket
  end

  test 'provision! can target another month via date:' do
    user = User.create!(email_address: 'monthlylog-other-month@example.com')
    target = Date.current.beginning_of_month.next_month

    monthlylog = Monthlylog.provision!(user, date: target)

    assert_equal target, monthlylog.period_from
    assert_nil user.monthlylogs.covering(Date.current).take
  end

  test 'does not create a daylog after create' do
    monthlylog = create_monthlylog!(@user, name: 'current')

    assert_nil @user.daylog
    assert_not_nil monthlylog.bucket
  end
end
