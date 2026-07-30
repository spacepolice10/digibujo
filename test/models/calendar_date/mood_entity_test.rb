# frozen_string_literal: true

require 'test_helper'

class CalendarDate::MoodEntityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_daylog!(@user)
    @calendar_date = @user.calendar_dates.create!(date: Date.current)
  end

  test 'creates mood entity for a day' do
    entity = CalendarDate::MoodEntity.create!(calendar_date: @calendar_date, mood: :inspired)

    assert_equal 'inspired', entity.mood
    assert_equal '✨', entity.marker
    assert_equal Date.current, entity.date
  end

  test 'enforces one entity per date' do
    CalendarDate::MoodEntity.create!(calendar_date: @calendar_date, mood: :positive)
    duplicate = CalendarDate::MoodEntity.new(calendar_date: @calendar_date, mood: :negative)

    assert_not duplicate.valid?
  end
end
