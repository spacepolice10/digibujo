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
    blob = attach_calendar_date_picture_blob!(@user, filename: 'day.png')

    get attachment_path(blob.signed_id)

    assert_response :success
    assert_match 'day.png', response.body
  end

  test 'show returns not found for another users daylog picture' do
    other = users(:two)
    blob = attach_calendar_date_picture_blob!(other, filename: 'foreign-day.png')

    get attachment_path(blob.signed_id)

    assert_response :not_found
  end

  test 'index lists all owned upload types and excludes another users files' do
    rich_text_blob = attach_note_blob!(@user, filename: 'inline.png')
    picture_blob = attach_calendar_date_picture_blob!(@user, filename: 'picture.png')
    voice_blob = attach_voice_blob!(@user, filename: 'memo.webm')
    foreign_blob = attach_note_blob!(users(:two), filename: 'foreign.png')

    get attachments_path

    assert_response :success
    assert_match rich_text_blob.filename.to_s, response.body
    assert_match picture_blob.filename.to_s, response.body
    assert_match voice_blob.filename.to_s, response.body
    assert_no_match foreign_blob.filename.to_s, response.body
  end

  private

  def attach_note_blob!(user, filename:)
    bullet = create_bullet!(user, bulletable: Note.new, body: '<p>note</p>')
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(mini_png),
      filename: filename,
      content_type: 'image/png'
    )
    content = ActionText::Content.new('<p>note</p>').append_attachables(blob)
    bullet.update!(body: content)
    blob
  end

  def attach_calendar_date_picture_blob!(user, filename:)
    calendar_date = user.calendar_dates.create!(date: Date.current)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(mini_png),
      filename: filename,
      content_type: 'image/png'
    )
    picture = calendar_date.build_picture
    picture.picture.attach(blob)
    picture.save!
    blob
  end

  def attach_voice_blob!(user, filename:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('voice memo'),
      filename: filename,
      content_type: 'audio/webm'
    )
    voice = Voice.new(duration_seconds: 1)
    voice.recording.attach(blob)
    create_bullet!(user, bulletable: voice, body: 'Voice memo')
    blob
  end

  def mini_png
    Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
end
