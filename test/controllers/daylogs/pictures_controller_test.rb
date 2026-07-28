# frozen_string_literal: true

require 'test_helper'

class Daylogs::PicturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
    @date = Date.current
    @picture_dom_id = "daylog_picture_#{@date.iso8601}"
    @header_photo_dom_id = "daylog_header_photo_#{@date.iso8601}"
  end

  test 'create picture updates control and header photo via turbo stream' do
    assert_difference -> { @user.daylog.pictures.count }, 1 do
      post daylog_picture_path,
           params: { date: @date.iso8601, picture: upload_png },
           as: :turbo_stream
    end

    assert_response :success
    assert @user.daylog.pictures.find_by!(date: @date).picture.attached?
    assert_select "turbo-stream[action=replace][target=#{@picture_dom_id}]", count: 1
    assert_select "turbo-stream[action=replace][target=#{@header_photo_dom_id}]", count: 1
  end

  test 'create picture redirects html requests to daylog' do
    assert_difference -> { @user.daylog.pictures.count }, 1 do
      post daylog_picture_path, params: { date: @date.iso8601, picture: upload_png }
    end

    assert_redirected_to daylog_path(date: @date.iso8601)
    assert @user.daylog.pictures.find_by!(date: @date).picture.attached?
  end

  test 'destroy picture updates control and header photo via turbo stream' do
    attach_picture!

    assert_difference -> { @user.daylog.pictures.count }, -1 do
      delete daylog_picture_path,
             params: { date: @date.iso8601 },
             as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{@picture_dom_id}]", count: 1
    assert_select "turbo-stream[action=replace][target=#{@header_photo_dom_id}]", count: 1
  end

  test 'destroy picture redirects html requests to daylog' do
    attach_picture!

    assert_difference -> { @user.daylog.pictures.count }, -1 do
      delete daylog_picture_path, params: { date: @date.iso8601 }
    end

    assert_redirected_to daylog_path(date: @date.iso8601)
  end

  private

  def attach_picture!
    picture = @user.daylog.pictures.new(date: @date)
    picture.picture.attach(
      io: StringIO.new(mini_png),
      filename: 'day.png',
      content_type: 'image/png'
    )
    picture.save!
  end

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
