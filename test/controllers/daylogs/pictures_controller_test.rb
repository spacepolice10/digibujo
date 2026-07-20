# frozen_string_literal: true

require 'test_helper'

class Daylogs::PicturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
    @date = Date.current
  end

  test 'create picture' do
    assert_difference -> { @user.daylog.pictures.count }, 1 do
      post daylog_picture_path, params: { date: @date.iso8601, image: upload_png }
    end

    assert_redirected_to daylog_path(date: @date.iso8601)
    assert @user.daylog.pictures.find_by!(date: @date).image.attached?
  end

  test 'destroy picture' do
    picture = @user.daylog.pictures.new(date: @date)
    picture.image.attach(
      io: StringIO.new(mini_png),
      filename: 'day.png',
      content_type: 'image/png'
    )
    picture.save!

    assert_difference -> { @user.daylog.pictures.count }, -1 do
      delete daylog_picture_path, params: { date: @date.iso8601 }
    end

    assert_redirected_to daylog_path(date: @date.iso8601)
  end

  private

  def upload_png
    file = Tempfile.new([ 'day', '.png' ])
    file.binmode
    file.write(mini_png)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'image/png')
  end

  def mini_png
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
end
