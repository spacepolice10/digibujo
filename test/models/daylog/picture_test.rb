# frozen_string_literal: true

require 'test_helper'

class Daylog::PictureTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_daylog!(@user)
    @daylog = @user.reload.daylog
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(mini_png),
      filename: 'day.png',
      content_type: 'image/png'
    )
  end

  test 'creates picture for a day' do
    picture = @daylog.pictures.new(date: Date.current)
    picture.image.attach(@blob)

    assert picture.save
    assert picture.image.attached?
  end

  test 'requires image' do
    picture = @daylog.pictures.new(date: Date.current)

    assert_not picture.valid?
    assert_includes picture.errors[:image], "can't be blank"
  end

  test 'rejects unsupported content type' do
    bad = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('not-an-image'),
      filename: 'day.txt',
      content_type: 'text/plain'
    )
    picture = @daylog.pictures.new(date: Date.current)
    picture.image.attach(bad)

    assert_not picture.valid?
    assert_includes picture.errors[:image], 'has an invalid content type'
  end

  test 'enforces one picture per date' do
    first = @daylog.pictures.new(date: Date.current)
    first.image.attach(@blob)
    first.save!

    duplicate = @daylog.pictures.new(date: Date.current)
    duplicate.image.attach(@blob)

    assert_not duplicate.valid?
  end

  private

  def mini_png
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
end
