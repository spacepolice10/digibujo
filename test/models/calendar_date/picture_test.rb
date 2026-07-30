# frozen_string_literal: true

require 'test_helper'

class CalendarDate::PictureTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_daylog!(@user)
    @calendar_date = @user.calendar_dates.create!(date: Date.current)
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(mini_png),
      filename: 'day.png',
      content_type: 'image/png'
    )
  end

  test 'creates picture for a day' do
    picture = @calendar_date.build_picture
    picture.picture.attach(@blob)

    assert picture.save
    assert picture.picture.attached?
  end

  test 'requires picture' do
    picture = @calendar_date.build_picture

    assert_not picture.valid?
    assert_includes picture.errors[:picture], "can't be blank"
  end

  test 'rejects unsupported content type' do
    bad = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('not-an-image'),
      filename: 'day.txt',
      content_type: 'text/plain'
    )
    picture = @calendar_date.build_picture
    picture.picture.attach(bad)

    assert_not picture.valid?
    assert_includes picture.errors[:picture], 'has an invalid content type'
  end

  test 'enforces one picture per date' do
    first = @calendar_date.build_picture
    first.picture.attach(@blob)
    first.save!

    duplicate = CalendarDate::Picture.new(calendar_date: @calendar_date)
    duplicate.picture.attach(@blob)

    assert_not duplicate.valid?
  end

  private

  def mini_png
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
end
