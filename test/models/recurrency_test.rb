# frozen_string_literal: true

require "test_helper"

class RecurrencyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @recurrency = @user.recurrencies.create!(name: "Run", schedule: { "days" => (0..6).to_a })
  end

  test "scheduled_on matches selected days" do
    today = Date.current

    assert @recurrency.scheduled_on?(today)
    assert @recurrency.scheduled_on?(today + 1.day)
  end

  test "scheduled_on skips unselected days" do
    today = Date.current
    @recurrency.update!(schedule: { "days" => [today.wday] })

    assert @recurrency.scheduled_on?(today)
    assert_not @recurrency.scheduled_on?(today + 1.day)
  end

  test "active_from is creation date" do
    assert_equal @recurrency.created_at.to_date, @recurrency.active_from
  end

  test "scheduled_on false before creation date" do
    @recurrency.update_column(:created_at, 1.day.from_now.in_time_zone.beginning_of_day)

    assert_not @recurrency.scheduled_on?(Date.current)
  end

  test "destroy restricted when completions exist" do
    @recurrency.completions.create!(date: Date.current, completed_at: Time.current)

    assert_not @recurrency.destroy
    assert @recurrency.persisted?
  end
end
