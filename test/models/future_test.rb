# frozen_string_literal: true

require 'test_helper'

class FutureTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @future = ensure_future!(@user)
  end

  test 'allows multiple futures per user with different period_from' do
    other = Future.new(user: @user, period_from: Date.current.beginning_of_month + 6.months)

    assert other.valid?
  end

  test 'normalizes period_to to end of six-month spread' do
    from = Date.new(2027, 1, 1)
    future = Future.create!(user: @user, period_from: from)

    assert_equal from, future.period_from
    assert_equal Date.new(2027, 6, 30), future.period_to
  end


  test 'spread_months returns six month-start dates from period_from' do
    @future.update!(period_from: Date.new(2026, 7, 1))

    months = @future.spread_months

    assert_equal 6, months.size
    assert_equal Date.new(2026, 7, 1), months.first
    assert_equal Date.new(2026, 12, 1), months.last
    assert months.all? { |d| d == d.beginning_of_month }
  end

  test 'covering finds future for a date inside its period' do
    @future.update!(period_from: Date.new(2026, 7, 1))

    assert_equal @future, @user.futures.covering(Date.new(2026, 9, 15)).take
    assert_nil @user.futures.covering(Date.new(2027, 2, 1)).take
  end

  test 'future bullets group by pops_on month and unplanned' do
    planned = create_bullet!(@user,
      bulletable: Task.new, body: 'July goal',
      bucket: @future.bucket,
      pops_on: @future.period_from
    )
    unplanned = create_bullet!(@user,
      bulletable: Task.new, body: 'Someday',
      bucket: @future.bucket,
      pops_on: nil
    )

    months = @future.spread_months
    by_month = @future.bullets.where(pops_on: months).group_by { |b| b.pops_on.beginning_of_month }

    assert_includes by_month[@future.period_from].map(&:id), planned.id
    assert_includes @future.bullets.where(pops_on: nil).pluck(:id), unplanned.id
  end
end
