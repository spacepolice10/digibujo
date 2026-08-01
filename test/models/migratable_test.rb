# frozen_string_literal: true

require 'test_helper'

class MigratableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @bullet = create_bullet!(@user, bulletable: Task.new(body: 'Task'), pops_on: Date.current)
  end

  test 'mark_migration! sets migrated_at and last_migration' do
    @bullet.mark_migration!(action: 'rescheduled', from_pops_on: Date.current, to_pops_on: Date.current + 1)

    @bullet.reload
    assert @bullet.migrated_at.present?
    assert_equal 'rescheduled', @bullet.last_migration['action']
    assert_equal Date.current.iso8601, @bullet.last_migration['from_pops_on']
  end

  test 'mark_migration! records activity with metadata' do
    assert_difference -> { Activity.count }, 1 do
      @bullet.mark_migration!(action: 'rescheduled', pops_on: Date.current)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'rescheduled', activity.action
    assert_equal 'rescheduled', activity.metadata['action']
    assert_equal @bullet, activity.subject
  end

  test 'mark_migration! rejects non-BuJo actions' do
    assert_raises ArgumentError do
      @bullet.mark_migration!(action: 'acknowledged', pops_on: Date.current)
    end
  end

  test 'migrated? is false before stamp' do
    assert_not @bullet.migrated?
  end

  test 'postpone! with date change marks rescheduled migration' do
    daylog = ensure_daylog!(@user)
    @bullet.postpone!(bucket: daylog, pops_on: Date.current + 2.days)

    @bullet.reload
    assert @bullet.migrated?
    assert_equal 'rescheduled', @bullet.last_migration['action']
  end

  test 'postpone! without date change does not mark migration' do
    daylog = ensure_daylog!(@user)
    @bullet.update!(pops_on: Date.current)

    assert_no_difference -> { Activity.count } do
      @bullet.postpone!(bucket: daylog, pops_on: Date.current)
    end

    @bullet.reload
    assert_not @bullet.migrated?
  end

  test 'collect! marks collected migration' do
    collection = create_collection!(@user, name: 'Inbox')

    @bullet.collect!(bucket_id: collection.bucket.id)

    @bullet.reload
    assert @bullet.migrated?
    assert_equal 'collected', @bullet.last_migration['action']
    assert_equal collection.bucket.id, @bullet.last_migration['bucket_id']
  end

  test 'migrate_to! future keeps month-start pops_on when caller resolves it' do
    future = ensure_future!(@user)
    month = Date.current.beginning_of_month

    @bullet.migrate_to!(bucket: future.bucket, pops_on: month, action: 'rescheduled')

    @bullet.reload
    assert_equal future.bucket.id, @bullet.bucket_id
    assert_equal month, @bullet.pops_on
    assert_equal 'rescheduled', @bullet.last_migration['action']
  end

  test 'postpone! sometime clears pops_on on future' do
    future = ensure_future!(@user)

    @bullet.postpone!(bucket: future.bucket, pops_on: nil)

    @bullet.reload
    assert_equal future.bucket.id, @bullet.bucket_id
    assert_nil @bullet.pops_on
    assert_equal 'rescheduled', @bullet.last_migration['action']
  end

  test 'complete! marks migrated_at without BuJo migration action' do
    @bullet.bulletable.complete!

    @bullet.reload
    assert @bullet.migrated?
    assert_equal({}, @bullet.last_migration)
    assert_equal 'completed', Activity.order(:created_at).last.action
  end

  test 'archive! does not mark migration' do
    @bullet.archive!

    assert @bullet.archived?
    assert_not @bullet.migrated?
  end

  test 'migration_hint describes rescheduled move between days' do
    from = Date.current
    to = Date.current + 2.days
    @bullet.update!(pops_on: to)
    @bullet.mark_migration!(action: 'rescheduled', from_pops_on: from, to_pops_on: to)

    assert_includes @bullet.migration_hint, from.strftime('%a, %b %-d')
    assert_includes @bullet.migration_hint, to.strftime('%a, %b %-d')
    assert_match(/Rescheduled from/, @bullet.migration_hint)
  end

  test 'migration_hint describes collection' do
    @bullet.mark_migration!(action: 'collected', bucket_id: 1, bucket_name: 'Reading list')

    assert_equal 'Moved into Reading list.', @bullet.migration_hint
  end

  test 'migration_hint is nil when not migrated' do
    assert_nil @bullet.migration_hint
  end

  test 'migration_hint is nil for complete-only stamp' do
    @bullet.bulletable.complete!

    assert_nil @bullet.migration_hint
  end
end
