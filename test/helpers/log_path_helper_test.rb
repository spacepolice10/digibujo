# frozen_string_literal: true

require "test_helper"

class LogPathHelperTest < ActionView::TestCase
  include LogPathHelper

  test "daylog_path_to uses bare daylog for today" do
    travel_to Date.new(2026, 5, 21) do
      assert_equal daylog_path, daylog_path_to(Date.current)
    end
  end

  test "daylog_path_to uses dated path for other days" do
    date = Date.new(2026, 4, 14)
    assert_equal daylog_on_path(year: 2026, month: 4, day: 14), daylog_path_to(date)
  end

  test "monthlylog_path_to uses bare monthlylog for current month" do
    travel_to Date.new(2026, 5, 21) do
      assert_equal monthlylog_path, monthlylog_path_to(Date.current)
    end
  end

  test "monthlylog_path_to uses dated path for other months" do
    date = Date.new(2025, 4, 10)
    assert_equal monthlylog_on_path(year: 2025, month: 4), monthlylog_path_to(date)
  end
end
