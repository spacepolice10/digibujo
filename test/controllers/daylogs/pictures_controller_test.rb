# frozen_string_literal: true

require 'test_helper'

class Daylogs::PicturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ensure_daylog!(@user)
    @date = Date.current
    @picture_dom_id = "daylog_picture_#{@date.iso8601}"
    @photo_card_dom_id = "daylog_photo_card_#{@date.iso8601}"
    @calendar_date = @user.calendar_dates.create!(date: @date)
  end

  test 'create picture updates control and photo card via turbo stream' do
    assert_difference -> { @user.daylog.pictures.count }, 1 do
      post daylog_picture_path,
           params: { date: @date.iso8601, picture: upload_png },
           as: :turbo_stream
    end

    assert_response :success
    assert @calendar_date.reload.picture.picture.attached?
    assert_select "turbo-stream[action=replace][target=#{@picture_dom_id}]", count: 1
    assert_select "turbo-stream[action=replace][target=#{@photo_card_dom_id}]", count: 1
  end

  test 'create picture keeps the photo card empty on mobile' do
    post daylog_picture_path,
         params: { date: @date.iso8601, picture: upload_png },
         headers: { 'User-Agent' => 'iPhone' },
         as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{@photo_card_dom_id}]" do
      assert_select '.daylog--photo-card', count: 0
      assert_select 'img', count: 0
    end
  end

  test 'show picture returns the card fragment' do
    attach_picture!

    get daylog_picture_path(date: @date.iso8601)

    assert_response :success
    assert_select '.daylog--photo-card' do
      assert_select 'img.daylog--photo-card-image'
      assert_select '.daylog--photo-toolbar'
    end
    assert_no_match(/<body/i, response.body)
    assert_no_match(/daylog--shell/, response.body)
  end

  test 'show picture returns not found when missing' do
    get daylog_picture_path(date: @date.iso8601)

    assert_response :not_found
  end

  test 'create picture redirects html requests to daylog' do
    assert_difference -> { @user.daylog.pictures.count }, 1 do
      post daylog_picture_path, params: { date: @date.iso8601, picture: upload_png }
    end

    assert_redirected_to daylog_path(date: @date.iso8601)
    assert @calendar_date.reload.picture.picture.attached?
  end

  test 'destroy picture updates control and photo card via turbo stream' do
    attach_picture!

    assert_difference -> { @user.daylog.pictures.count }, -1 do
      delete daylog_picture_path,
             params: { date: @date.iso8601 },
             as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{@picture_dom_id}]", count: 1
    assert_select "turbo-stream[action=replace][target=#{@photo_card_dom_id}]", count: 1
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
    picture = @user.daylog.pictures.new(calendar_date: @calendar_date)
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
