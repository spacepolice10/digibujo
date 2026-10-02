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

    assert_equal :circle, bullet.marker_icon
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

  test 'an attachment bullet is searchable by its filename' do
    blob = create_blob!(filename: 'quarterly report.pdf')
    bullet = create_bullet!(@user, bulletable: Attachment.new.tap { |a| a.file.attach(blob) })

    assert_equal 'quarterly report.pdf', bullet.reload.filename
    assert_includes bullet.search_body, 'quarterly report.pdf'
  end

  test 'only text and attachment bullets exist' do
    assert_equal %w[Text Attachment], Bullet.bulletable_types
  end

  test 'name falls back to the bulletable default when the body is blank' do
    assert_equal 'Untitled', create_bullet!(@user, body: '').name
  end

  test 'collect tags the bullet and leaves it on the timeline' do
    collection = create_collection!(@user, name: 'Ideas')
    bullet = create_bullet!(@user, body: 'File me')

    assert_includes @user.timeline.bullets, bullet
    bullet.collect!(collection_id: collection.id)

    assert_includes bullet.reload.collections, collection
    assert_includes @user.timeline.bullets, bullet
  end

  test 'collect can attach many collections to one bullet' do
    first = create_collection!(@user, name: 'ideas')
    second = create_collection!(@user, name: 'later')
    bullet = create_bullet!(@user, body: 'Shared')

    bullet.collect!(collection_id: first.id)
    bullet.collect!(collection_id: second.id)
    bullet.collect!(collection_id: first.id)

    assert_equal [first.id, second.id].sort, bullet.reload.collection_ids.sort
  end

  test 'postponing into the future moves the bullet to upcoming' do
    bullet = create_bullet!(@user, body: 'Later')

    bullet.postpone!(pops_on: Date.current + 2)

    assert_not_includes @user.timeline.bullets, bullet
    assert_includes @user.timeline.upcoming, bullet
  end
end
