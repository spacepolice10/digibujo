# frozen_string_literal: true

require 'test_helper'

class CalendarDateTest < ActiveSupport::TestCase
  test 'pick_mood creates or updates mood entity' do
    user = users(:one)
    ensure_daylog!(user)

    calendar_date = user.calendar_dates.find_or_create_by!(date: Date.current)
    entity = calendar_date.pick_mood(:inspired)
    assert_equal 'inspired', entity.mood

    updated = calendar_date.pick_mood(:positive)
    assert_equal entity.id, updated.id
    assert_equal 'positive', updated.mood
  end

  test 'remove_mood destroys the entity for that date' do
    user = users(:one)
    ensure_daylog!(user)
    calendar_date = user.calendar_dates.find_or_create_by!(date: Date.current)
    calendar_date.pick_mood(:negative)

    assert_difference -> { CalendarDate::MoodEntity.count }, -1 do
      calendar_date.remove_mood
    end
  end

  test 'mood_entities_by_date indexes by date' do
    user = users(:one)
    ensure_daylog!(user)
    today = Date.current
    calendar_date = user.calendar_dates.find_or_create_by!(date: today)
    entity = calendar_date.pick_mood(:frustrated)

    assert_equal({ today => entity }, CalendarDate.mood_entities_by_date(user, [today, today + 1.day]))
  end

  test 'remove_picture destroys the picture for that date' do
    user = users(:one)
    ensure_daylog!(user)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')),
      filename: 'day.png',
      content_type: 'image/png'
    )
    calendar_date = user.calendar_dates.create!(date: Date.current)
    picture = calendar_date.build_picture
    picture.picture.attach(blob)
    picture.save!

    assert_difference -> { CalendarDate::Picture.count }, -1 do
      calendar_date.remove_picture
    end
  end
end
