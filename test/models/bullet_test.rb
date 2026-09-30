# frozen_string_literal: true

require 'test_helper'

class BulletTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'pops_on defaults to today' do
    bullet = create_bullet!(@user, body: 'Fresh')

    assert_equal Date.current, bullet.pops_on
  end

  test 'text is the default marker and done swaps it for a check' do
    bullet = create_bullet!(@user, body: 'Do it')

    assert_equal :square, bullet.marker_icon
    bullet.complete!
    assert_equal :check, bullet.marker_icon
  end

  test 'complete and uncomplete toggle done' do
    bullet = create_bullet!(@user, body: 'Do it')

    assert_not bullet.done?
    bullet.complete!
    assert bullet.reload.done?
    assert_not_nil bullet.done_at
    bullet.uncomplete!
    assert_not bullet.reload.done?
    assert_nil bullet.done_at
  end

  test 'only text and memo bullets exist' do
    assert_equal %w[Text Memo], Bullet.bulletable_types
  end

  test 'collect moves the bullet off the timeline' do
    collection = create_collection!(@user, name: 'Ideas')
    bullet = create_bullet!(@user, body: 'File me')

    assert_includes @user.timeline.bullets, bullet
    bullet.collect!(collection_id: collection.id)

    assert_equal collection, bullet.reload.collection
    assert_not_includes @user.timeline.bullets, bullet
  end

  test 'postponing into the future moves the bullet to upcoming' do
    bullet = create_bullet!(@user, body: 'Later')

    bullet.postpone!(pops_on: Date.current + 2)

    assert_not_includes @user.timeline.bullets, bullet
    assert_includes @user.timeline.upcoming, bullet
  end
end
