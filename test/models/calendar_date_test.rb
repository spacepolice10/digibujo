# frozen_string_literal: true

require 'test_helper'

class CalendarDateTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @calendar_date = @user.calendar_dates.create!(date: Date.current)
  end

  test 'belongs to user' do
    assert_equal @user, @calendar_date.user
  end

  test 'validates date uniqueness scoped to user' do
    duplicate = @user.calendar_dates.new(date: Date.current)
    assert_not duplicate.valid?
  end

  test 'allows same date on different users' do
    other_user = users(:two)
    other_date = other_user.calendar_dates.create!(date: Date.current)
    assert other_date.valid?
  end
end
