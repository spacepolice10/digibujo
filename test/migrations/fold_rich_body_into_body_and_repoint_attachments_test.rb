# frozen_string_literal: true

require 'test_helper'
require 'action_text'
require Rails.root.join('db/migrate/20260625120000_fold_rich_body_into_body_and_repoint_attachments')

class FoldRichBodyIntoBodyAndRepointAttachmentsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'Note with rich_body folds into body and deletes rich_body row' do
    note_bullet = create_note_bullet(body_html: '<p>inline</p>', rich_body_html: '<p>details</p>')

    run_migration

    note_bullet.reload
    body_html = legacy_bullet_body_html(note_bullet)
    assert_includes body_html, '<hr>'
    assert_includes body_html, 'details'
    assert_equal 0, ActionText::RichText.where(name: 'rich_body', record: note_bullet).count
  end

  test 'Task with rich_body and blank body spawns standalone Note and auto-archives the Task' do
    task_bullet = create_task_bullet(body_html: nil, rich_body_html: '<p>long details</p>')

    run_migration

    spawned = Bullet.where(bulletable_type: 'Note', user: @user).order(created_at: :desc).first
    assert spawned
    assert_includes legacy_bullet_body_html(spawned), 'long details'

    task_bullet.reload
    assert task_bullet.archived?, 'expected blank-body original to be auto-archived'
  end

  test 'Task with body present keeps its body and is not archived' do
    task_bullet = create_task_bullet(body_html: '<p>ship it</p>', rich_body_html: '<p>extra</p>')

    run_migration

    task_bullet.reload
    refute task_bullet.archived?
    assert_includes legacy_bullet_body_html(task_bullet), 'ship it'
  end

  test 'Note with tray attachment embeds inline and deletes attachment rows' do
    note_bullet = create_note_bullet(body_html: '<p>note</p>', rich_body_html: nil)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('file contents'),
      filename: 'notes.txt',
      content_type: 'text/plain'
    )
    ActiveStorage::Attachment.create!(name: 'attachments', record: note_bullet, blob: blob)

    run_migration

    note_bullet.reload
    assert_includes legacy_bullet_body_html(note_bullet), 'action-text-attachment'
    assert_equal 0, ActiveStorage::Attachment.where(record_type: 'Bullet', record_id: note_bullet.id, name: 'attachments').count
  end

  private

  def create_note_bullet(body_html:, rich_body_html:)
    note = Note.create!
    bullet = Bullet.new(user: @user, bulletable: note, bucket: ensure_daylog!(@user))
    bullet.save!(validate: false)
    ActionText::RichText.create!(record: bullet, name: 'body', body: body_html) if body_html
    ActionText::RichText.create!(record: bullet, name: 'rich_body', body: rich_body_html) if rich_body_html
    bullet
  end

  def create_task_bullet(body_html:, rich_body_html:)
    task = Task.create!
    bullet = Bullet.new(user: @user, bulletable: task, bucket: ensure_daylog!(@user))
    bullet.save!(validate: false)
    ActionText::RichText.create!(record: bullet, name: 'body', body: body_html) if body_html
    ActionText::RichText.create!(record: bullet, name: 'rich_body', body: rich_body_html) if rich_body_html
    bullet
  end

  def run_migration
    FoldRichBodyIntoBodyAndRepointAttachments.new.up
  end

  def legacy_bullet_body_html(bullet)
    ActionText::RichText.find_by!(name: 'body', record_type: 'Bullet', record_id: bullet.id).body.to_s
  end
end
