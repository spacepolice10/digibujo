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

  test 'accepts valid colour and icon' do
    @bucket.update!(colour: 'teal', icon: 'calendar')
    assert_equal 'teal', @bucket.colour
    assert_equal 'calendar', @bucket.icon
  end

  test 'allows nil colour and icon' do
    @bucket.update!(colour: nil, icon: nil)
    assert_nil @bucket.colour
    assert_nil @bucket.icon
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
    @bucket.update!(colour: 'cobalt', icon: 'pin')
    assert_equal 'alpha', @collection.name
    assert_equal 'cobalt', @collection.colour
    assert_equal 'pin', @collection.icon
  end

  test 'collection names can be duplicated per user' do
    create_collection!(@user, name: 'reading')
    duplicate = Collection.create!
    bucket = @user.buckets.build(bucketable: duplicate, name: 'reading')
    assert bucket.valid?
  end

  test 'pin! marks bucket pinned' do
    assert_not @bucket.pinned?

    assert @bucket.pin!

    assert @bucket.reload.pinned?
  end

  test 'unpin! clears pinned state' do
    @bucket.pin!

    @bucket.unpin!

    assert_not @bucket.reload.pinned?
  end

  test 'collection bucket allows nil period' do
    assert @bucket.valid?
  end

  test 'search_body includes side note plain text' do
    @bucket.update!(side_note: '<p>Margin notes</p>')

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
    assert_equal 'Bucket', activity.subject_type
    assert_equal 'Collection', activity.metadata['bucketable_type']
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

  test 'archive! rejects future log bucket' do
    ensure_future_bucket!(@user)
    future_bucket = @user.future_bucket!.bucket

    assert_raises(ActiveRecord::RecordInvalid) { future_bucket.archive! }

    assert_not future_bucket.reload.archived?
  end

  test 'archive! rejects monthly bucket' do
    monthly_bucket = create_monthly_bucket!(@user, name: 'june')

    assert_raises(ActiveRecord::RecordInvalid) { monthly_bucket.bucket.archive! }

    assert_not monthly_bucket.bucket.reload.archived?
  end

  test 'archived collection bucket is not searchable' do
    @bucket.archive!

    assert_not @bucket.searchable?
  end
end
