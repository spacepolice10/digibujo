# frozen_string_literal: true

require "test_helper"

class RecurrencyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @recurrency = @user.recurrencies.create!(name: "Run", schedule: { "kind" => "daily" })
  end

  test "scheduled_on daily" do
    assert @recurrency.scheduled_on?(Date.current)
  end

  test "scheduled_on weekdays skips weekend" do
    @recurrency.update!(schedule: { "kind" => "weekdays" })
    monday = Date.current.beginning_of_week

    assert @recurrency.scheduled_on?(monday)
    assert_not @recurrency.scheduled_on?(monday + 5.days)
  end

  test "scheduled_on custom days" do
    monday = Date.current.beginning_of_week
    @recurrency.update!(schedule: { "kind" => "custom", "days" => [monday.wday] })

    assert @recurrency.scheduled_on?(monday)
    assert_not @recurrency.scheduled_on?(monday + 1.day)
  end

  test "active_on respects active_from and active_to" do
    @recurrency.update!(active_from: Date.current, active_to: Date.current + 2.days)

    assert_not @recurrency.active_on?(Date.current - 1.day)
    assert @recurrency.active_on?(Date.current + 1.day)
    assert_not @recurrency.active_on?(Date.current + 3.days)
  end

  test "scheduled_on false outside active range" do
    @recurrency.update!(active_to: Date.current - 1.day)

    assert_not @recurrency.scheduled_on?(Date.current)
  end

  test "retired when active_to in past" do
    @recurrency.update!(active_to: Date.current - 1.day)

    assert @recurrency.retired?
  end

  test "destroy restricted when completions exist" do
    @recurrency.completions.create!(date: Date.current, completed_at: Time.current)

    assert_not @recurrency.destroy
    assert @recurrency.persisted?
  end
end
