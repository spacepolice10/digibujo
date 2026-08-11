# frozen_string_literal: true

require 'test_helper'

class BucketTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @collection = create_collection!(@user, name: 'alpha')
    @bucket = @collection.bucket
  end

  test 'requires name' do
    @bucket.name = ''
    assert_not @bucket.valid?
  end

  test 'normalizes name' do
    @bucket.update!(name: '  Beta  ')
    assert_equal 'beta', @bucket.name
  end

  test 'matching_name filters by prefix' do
    create_collection!(@user, name: 'alpine')
    create_collection!(@user, name: 'zeta')

    assert_equal %w[alpha alpine], @user.buckets.matching_name('al').order(:name).pluck(:name)
    assert_equal @user.buckets.order(:name).pluck(:name),
                 @user.buckets.matching_name(nil).order(:name).pluck(:name)
  end

  test 'accepts valid colour and icon' do
    @bucket.update!(colour: 'teal', icon: 'calendar')
    assert_equal 'teal', @bucket.colour
    assert_equal 'calendar', @bucket.icon
  end

  test 'allows nil colour and icon' do
    @bucket.update!(colour: nil, icon: nil)
    assert_nil @bucket.colour
    assert_nil @bucket.icon
    assert_equal 'folder', @bucket.icon_name
    assert_equal 'folder', @bucket.icon_name
  end

  test 'rejects invalid colour' do
    @bucket.colour = 'crimson'
    assert_not @bucket.valid?
  end

  test 'rejects legacy numeric colour keys' do
    @bucket.colour = '3'
    assert_not @bucket.valid?
  end

  test 'rejects invalid icon' do
    @bucket.icon = 'invalid'
    assert_not @bucket.valid?
  end

  test 'bucketable delegates identity' do
    @bucket.update!(colour: 'cobalt', icon: 'folder')
    assert_equal 'alpha', @collection.name
    assert_equal 'cobalt', @collection.colour
    assert_equal 'folder', @collection.icon
  end

  test 'collection names can be duplicated per user' do
    create_collection!(@user, name: 'reading')
    duplicate = Collection.create!
    bucket = @user.buckets.build(bucketable: duplicate, name: 'reading')
    assert bucket.valid?
  end

  test 'pin! marks bucket pinned' do
    assert_not @bucket.pinned?

    assert_difference -> { Activity.count }, 1 do
      assert @bucket.pin!
    end

    assert @bucket.reload.pinned?
    activity = Activity.order(:created_at).last
    assert_equal 'pinned', activity.action
    assert_equal @bucket, activity.subject
    assert_equal 'Collection', activity.metadata['bucketable_type']
  end

  test 'unpin! clears pinned state' do
    @bucket.pin!

    assert_difference -> { Activity.count }, 1 do
      @bucket.unpin!
    end

    assert_not @bucket.reload.pinned?
    assert_equal 'unpinned', Activity.order(:created_at).last.action
  end

  test 'collection bucket allows nil period' do
    assert @bucket.valid?
  end

  test 'search_body includes collection description' do
    @collection.update!(description: 'Margin notes')

    assert_includes @bucket.search_body, 'alpha'
    assert_includes @bucket.search_body, 'Margin notes'
  end

  test 'archive! marks collection bucket archived and records activity' do
    assert_difference -> { Activity.count }, 1 do
      @bucket.archive!
    end

    assert @bucket.reload.archived?
    assert_equal Date.current, @bucket.archives_on
    activity = Activity.order(:created_at).last
    assert_equal 'archived', activity.action
    assert_equal 'Archive', activity.subject_type
    assert_equal @bucket.name, activity.metadata['name']
  end

  test 'unarchive! clears archived state and records activity' do
    @bucket.archive!

    assert_difference -> { Activity.count }, 1 do
      @bucket.unarchive!
    end

    assert_not @bucket.reload.archived?
    assert_nil @bucket.archives_on
    assert_equal 'unarchived', Activity.order(:created_at).last.action
  end

  test 'archived collection bucket is not searchable' do
    @bucket.archive!

    assert_not @bucket.searchable?
  end

  test 'archived bullet is not searchable' do
    bullet = create_bullet!(@user, bulletable: Task.new, body: 'Hide me', pops_on: Date.current)
    bullet.archive!

    assert_not bullet.searchable?
  end
end
