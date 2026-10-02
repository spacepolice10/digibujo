# frozen_string_literal: true

require 'test_helper'

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders own rich text attachment' do
    blob = attach_note_blob!(@user, filename: 'own.png')

    get attachment_path(blob.signed_id)

    assert_response :success
    assert_match 'own.png', response.body
  end

  test 'show renders a file owned by an attachment bullet' do
    blob = attach_file_blob!(@user, filename: 'report.pdf')

    get attachment_path(blob.signed_id)

    assert_response :success
    assert_match 'report.pdf', response.body
  end

  test 'show returns not found for another users attachment bullet file' do
    blob = attach_file_blob!(users(:two), filename: 'foreign.pdf')

    get attachment_path(blob.signed_id)

    assert_response :not_found
  end

  test 'show returns not found for another users rich text attachment' do
    other = users(:two)
    blob = attach_note_blob!(other, filename: 'foreign.png')

    get attachment_path(blob.signed_id)

    assert_response :not_found
  end

  test 'show returns not found for invalid signed id' do
    get attachment_path('not-a-valid-signed-id')

    assert_response :not_found
  end

  test 'index lists all owned upload types and excludes another users files' do
    rich_text_blob = attach_note_blob!(@user, filename: 'inline.png')
    file_blob = attach_file_blob!(@user, filename: 'report.pdf')
    foreign_blob = attach_note_blob!(users(:two), filename: 'foreign.png')

    get attachments_path

    assert_response :success
    assert_select 'nav.tabbar--back a[href=?][aria-label=?]', search_path, 'Back', text: 'Back'
    assert_select 'a[aria-label="Back to Home"]', count: 0
    assert_match rich_text_blob.filename.to_s, response.body
    assert_match file_blob.filename.to_s, response.body
    assert_no_match foreign_blob.filename.to_s, response.body
  end

  private

  def attach_note_blob!(user, filename:)
    bullet = create_bullet!(user, body: '<p>note</p>')
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(mini_png),
      filename: filename,
      content_type: 'image/png'
    )
    content = ActionText::Content.new('<p>note</p>').append_attachables(blob)
    bullet.update!(body: content)
    blob
  end

  def attach_file_blob!(user, filename:)
    bullet = create_file_bullet!(user, filename: filename, content_type: 'application/pdf', io: StringIO.new('%PDF-1.4'))
    bullet.file.blob
  end

  def mini_png
    Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
end
