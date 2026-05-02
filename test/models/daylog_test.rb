# frozen_string_literal: true

require "test_helper"

class DaylogTest < ActiveSupport::TestCase
  test "mood attribute assignment" do
    daylog = Daylog.new(mood: "excellent")
    assert_equal "excellent", daylog.mood
  end

  test "mood from string" do
    daylog = Daylog.new(mood: "fine")
    assert_equal "fine", daylog.mood
  end

  test "creates with mood from controller params" do
    bulletable_attrs = { "mood" => "excellent" }
    daylog = Daylog.new(bulletable_attrs)
    assert_equal "excellent", daylog.mood
  end
end