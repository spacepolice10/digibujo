# frozen_string_literal: true

require 'test_helper'

class DaylogTest < ActiveSupport::TestCase
  test 'provision! creates daylog and bucket' do
    user = User.create!(email_address: 'daylog-provision@example.com')

    daylog = Daylog.provision!(user)

    assert_equal daylog, user.reload.daylog
    assert_not_nil daylog.bucket
    assert_equal Onboarding::DAYLOG_NAME.downcase, daylog.bucket.name
    assert_equal Onboarding::DAYLOG_ICON, daylog.bucket.icon
    assert_not user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
  end

  test 'provision! is idempotent when daylog already exists' do
    user = User.create!(email_address: 'daylog-idempotent@example.com')
    first = Daylog.provision!(user)

    assert_no_difference -> { Daylog.where(user: user).count } do
      assert_equal first, Daylog.provision!(user)
    end
  end

  test 'provision! attaches bucket when daylog exists without one' do
    user = User.create!(email_address: 'daylog-orphan@example.com')
    daylog = user.create_daylog!

    repaired = Daylog.provision!(user)

    assert_equal daylog, repaired
    assert_not_nil repaired.bucket
  end

  test 'pick_mood creates or updates mood entity' do
    user = users(:one)
    ensure_daylog!(user)
    daylog = user.reload.daylog

    entity = daylog.pick_mood(date: Date.current, mood: :inspired)
    assert_equal 'inspired', entity.mood

    updated = daylog.pick_mood(date: Date.current, mood: :positive)
    assert_equal entity.id, updated.id
    assert_equal 'positive', updated.mood
  end

  test 'remove_mood destroys the entity for that date' do
    user = users(:one)
    ensure_daylog!(user)
    daylog = user.reload.daylog
    daylog.pick_mood(date: Date.current, mood: :negative)

    assert_difference -> { daylog.mood_entities.count }, -1 do
      daylog.remove_mood(date: Date.current)
    end
  end

  test 'mood_entities_by_date indexes by date' do
    user = users(:one)
    ensure_daylog!(user)
    daylog = user.reload.daylog
    today = Date.current
    entity = daylog.pick_mood(date: today, mood: :frustrated)

    assert_equal({ today => entity }, daylog.mood_entities_by_date([today, today + 1.day]))
  end

  test 'remove_picture destroys the picture for that date' do
    user = users(:one)
    ensure_daylog!(user)
    daylog = user.reload.daylog
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')),
      filename: 'day.png',
      content_type: 'image/png'
    )
    calendar_date = user.calendar_dates.create!(date: Date.current)
    picture = daylog.pictures.new(calendar_date: calendar_date)
    picture.picture.attach(blob)
    picture.save!

    assert_difference -> { daylog.pictures.count }, -1 do
      daylog.remove_picture(date: Date.current)
    end
  end
end
