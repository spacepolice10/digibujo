# frozen_string_literal: true

require 'test_helper'

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders own note attachment' do
    blob = attach_note_blob!(@user, filename: 'own.png')

    get attachment_path(blob.signed_id)

    assert_response :success
    assert_match 'own.png', response.body
  end

  test 'show returns not found for another users note attachment' do
    other = users(:two)
    blob = attach_note_blob!(other, filename: 'foreign.png')

    get attachment_path(blob.signed_id)

    assert_response :not_found
  end

  test 'show returns not found for invalid signed id' do
    get attachment_path('not-a-valid-signed-id')

    assert_response :not_found
  end

  test 'show renders own daylog picture' do
    blob = attach_daylog_picture_blob!(@user, filename: 'day.png')

    get attachment_path(blob.signed_id)

    assert_response :success
    assert_match 'day.png', response.body
  end

  test 'show returns not found for another users daylog picture' do
    other = users(:two)
    blob = attach_daylog_picture_blob!(other, filename: 'foreign-day.png')

    get attachment_path(blob.signed_id)

    assert_response :not_found
  end

  private

  def attach_note_blob!(user, filename:)
    bullet = create_bullet!(user, bulletable: Note.new(body: '<p>note</p>'))
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(mini_png),
      filename: filename,
      content_type: 'image/png'
    )
    bullet.bulletable.body.embeds.attach(blob)
    blob
  end

  def attach_daylog_picture_blob!(user, filename:)
    ensure_daylog!(user)
    daylog = user.reload.daylog
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(mini_png),
      filename: filename,
      content_type: 'image/png'
    )
    picture = daylog.pictures.new(date: Date.current)
    picture.picture.attach(blob)
    picture.save!
    blob
  end

  def mini_png
    Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
end
