# frozen_string_literal: true

require 'test_helper'

class BulletsHelperTest < ActionView::TestCase
  include BulletsHelper
  include IconHelper

  setup do
    @user = users(:one)
    @bucket_id = ensure_daylog!(@user).id
    @composer_id = 'test_bullets_composer'
    @pops_on = Date.current
  end

  test 'create_bullet_buttons renders all types with correct links and hotkeys' do
    html = create_bullet_buttons(
      composer_id: @composer_id,
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
      assert_includes html, %(data-turbo-frame="#{@composer_id}")
      assert_includes html, %(aria-label="Add #{type}")
    end

    assert_includes html, 'data-controller="hotkey"'
    assert_includes html, 'data-hotkey="Shift+T"'
  end

  test 'create_bullet_buttons renders subset of types' do
    html = create_bullet_buttons(
      composer_id: @composer_id,
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
        composer_id: @composer_id,
        bucket_id: @bucket_id,
        pops_on: @pops_on,
        bulletable_type: %w[Invalid]
      )
    end
  end
end
