# frozen_string_literal: true

require 'test_helper'
require 'action_text'
require Rails.root.join('db/migrate/20260808000000_move_body_rich_texts_to_bullets')

class MoveBodyRichTextsToBulletsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'repoints bulletable-owned body rows at the owning bullet' do
    bullet = create_bulletable_bul!(Task.new, body_html: '<p>ship it</p>')

    MoveBodyRichTextsToBullets.new.up

    row = ActionText::RichText.find_by(name: 'body', record_type: 'Bullet', record_id: bullet.id)
    assert row
    assert_includes row.body.to_html, 'ship it'
    assert_equal 0, ActionText::RichText.where(name: 'body', record_type: 'Task', record_id: bullet.bulletable_id).count
  end

  test 'moves rows for every bulletable type' do
    %w[Task Note Event Voice].map do |type|
      create_bulletable_bul!(type.constantize.new, body_html: "<p>#{type}</p>")
    end

    MoveBodyRichTextsToBullets.new.up

    %w[Task Note Event Voice].each do |type|
      bulletable = type.constantize.first
      row = ActionText::RichText.find_by(name: 'body', record_type: 'Bullet', record_id: bulletable.bullet.id)
      assert row, "expected Bullet row for #{type}"
      assert_equal type, row.body.to_plain_text.strip
    end
  end

  test 'down restores bulletable ownership' do
    bullet = create_bulletable_bul!(Note.new, body_html: '<p>note body</p>')

    MoveBodyRichTextsToBullets.new.up
    MoveBodyRichTextsToBullets.new.down

    assert_equal 1, ActionText::RichText.where(name: 'body', record_type: 'Note', record_id: bullet.bulletable_id).count
    assert_equal 0, ActionText::RichText.where(name: 'body', record_type: 'Bullet', record_id: bullet.id).count
  end

  private

  # Simulates the pre-migration layout: rich text hanging off the bulletable.
  def create_bulletable_bul!(bulletable, body_html:)
    bulletable.save!(validate: false)
    bullet = Bullet.new(user: @user, bulletable: bulletable, bucket: ensure_daylog!(@user))
    bullet.save!(validate: false)
    ActionText::RichText.create!(
      record_type: bulletable.class.name, record_id: bulletable.id,
      name: 'body', body: body_html
    )
    bullet
  end
end