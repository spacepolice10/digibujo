# frozen_string_literal: true

require 'test_helper'
require 'action_text'
require Rails.root.join('db/migrate/20260702090000_move_bullet_body_rich_texts_to_bulletables')

class MoveBulletBodyRichTextsToBulletablesTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'repoints Bullet-owned body rows at the bulletable' do
    bullet = create_legacy_bullet(Task.create!, body_html: '<p>ship it</p>')

    run_migration

    row = ActionText::RichText.find_by(name: 'body', record_type: 'Task', record_id: bullet.bulletable_id)
    assert row
    assert_includes row.body.to_html, 'ship it'
    assert_equal 0, ActionText::RichText.where(name: 'body', record_type: 'Bullet', record_id: bullet.id).count
    assert_equal 'ship it', bullet.reload.body.to_plain_text.strip
  end

  test 'leaves rows without a bulletable untouched' do
    orphan = Bullet.new(user: @user)
    orphan.save!(validate: false)
    ActionText::RichText.create!(record_type: 'Bullet', record_id: orphan.id, name: 'body', body: '<p>orphan</p>')

    run_migration

    assert_equal 1, ActionText::RichText.where(name: 'body', record_type: 'Bullet', record_id: orphan.id).count
  end

  test 'down restores Bullet ownership' do
    bullet = create_legacy_bullet(Note.create!, body_html: '<p>note body</p>')

    run_migration
    MoveBulletBodyRichTextsToBulletables.new.down

    assert_equal 1, ActionText::RichText.where(name: 'body', record_type: 'Bullet', record_id: bullet.id).count
    assert_equal 0, ActionText::RichText.where(name: 'body', record_type: 'Note', record_id: bullet.bulletable_id).count
  end

  private

  def create_legacy_bullet(bulletable, body_html:)
    bullet = Bullet.new(user: @user, bulletable: bulletable)
    bullet.save!(validate: false)
    ActionText::RichText.create!(record_type: 'Bullet', record_id: bullet.id, name: 'body', body: body_html)
    bullet
  end

  def run_migration
    MoveBulletBodyRichTextsToBulletables.new.up
  end
end
