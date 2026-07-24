# frozen_string_literal: true

require 'test_helper'

class BulletsHelperTest < ActionView::TestCase
  include BulletsHelper
  include IconHelper

  setup do
    @user = users(:one)
    @bucket_id = ensure_daylog!(@user).id
    @pops_on = Date.current
  end

  test 'create_bullet_buttons renders all types with _top links and hotkeys' do
    html = create_bullet_buttons(
      bucket_id: @bucket_id,
      pops_on: @pops_on,
      bulletable_type: Bullet.bulletable_types
    )

    Bullet.bulletable_types.each do |type|
      assert_match new_bullet_path(
        pops_on: @pops_on,
        bucket_id: @bucket_id,
        bulletable_type: type
      ).gsub('&', '&amp;'),
                   html
      assert_includes html, %(data-turbo-frame="_top")
      assert_includes html, %(data-composer-expand="true")
      assert_includes html, %(aria-label="Add #{type}")
    end

    assert_includes html, 'data-controller="hotkey"'
    assert_includes html, 'data-hotkey="Shift+T"'
    refute_includes html, 'commandfor'
    refute_includes html, 'haspopup'
  end

  test 'create_bullet_buttons renders subset of types' do
    html = create_bullet_buttons(
      bucket_id: @bucket_id,
      pops_on: @pops_on,
      bulletable_type: %w[Task Event]
    )

    assert_includes html, %(aria-label="Add Task")
    assert_includes html, %(aria-label="Add Event")
    refute_includes html, %(aria-label="Add Note")
    refute_includes html, %(aria-label="Add Voice")
  end

  test 'create_bullet_buttons raises for unknown type' do
    assert_raises(ArgumentError, match: /Unknown bullet type: Invalid/) do
      create_bullet_buttons(
        bucket_id: @bucket_id,
        pops_on: @pops_on,
        bulletable_type: %w[Invalid]
      )
    end
  end

  test 'bullet_composer_return_path resolves daylog date' do
    bucket = ensure_daylog!(@user)
    bullet = @user.bullets.new(bucket_id: bucket.id, pops_on: @pops_on)

    assert_equal daylog_path(date: @pops_on.iso8601), bullet_composer_return_path(bullet)
  end
end
