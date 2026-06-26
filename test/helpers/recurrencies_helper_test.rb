# frozen_string_literal: true

require "test_helper"

class RecurrenciesHelperTest < ActionView::TestCase
  include RecurrenciesHelper

  setup do
    @user = users(:one)
    @recurrency = @user.recurrencies.create!(name: "Run", schedule: { "days" => [1, 3, 5] })
    @from = Date.current.beginning_of_month
    @to = Date.current.end_of_month
    @tracker = RecurrencyTracker.new(user: @user, from: @from, to: @to)
  end

  test "recurrency_schedule_label lists abbreviated days" do
    assert_equal "Mon, Wed, Fri", recurrency_schedule_label(@recurrency)
  end

  test "recurrency_schedule_label uses every day for full week" do
    @recurrency.update!(schedule: { "days" => (0..6).to_a })

    assert_equal "Every day", recurrency_schedule_label(@recurrency)
  end

  test "recurrency_hint includes name schedule and completion" do
    day = Date.current
    @recurrency.update!(schedule: { "days" => [day.wday] })
    @recurrency.completions.create!(date: day, completed_at: Time.current)
    tracker = RecurrencyTracker.new(user: @user, from: @from, to: @to)

    hint = recurrency_hint(@recurrency, tracker: tracker, date: day)

    assert_match "Run", hint
    assert_match Date::ABBR_DAYNAMES[day.wday], hint
    assert_match "Done today", hint
  end
end
