# frozen_string_literal: true

require 'test_helper'

class MigratableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task', pops_on: Date.current)
  end

  test 'mark_migration! sets migrated_at and last_migration' do
    @bullet.mark_migration!(action: 'popped', from_pops_on: Date.current, to_pops_on: Date.current + 1)

    @bullet.reload
    assert @bullet.migrated_at.present?
    assert_equal 'popped', @bullet.last_migration['action']
    assert_equal Date.current.iso8601, @bullet.last_migration['from_pops_on']
  end

  test 'mark_migration! records activity with metadata' do
    assert_difference -> { Activity.count }, 1 do
      @bullet.mark_migration!(action: 'archived', pops_on: Date.current)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'archived', activity.action
    assert_equal 'archived', activity.metadata['action']
    assert_equal @bullet, activity.subject
  end

  test 'migrated? is false before stamp' do
    assert_not @bullet.migrated?
  end

  test 'pop! with date change marks popped migration' do
    @bullet.pop!(pops_on: Date.current + 2.days)

    @bullet.reload
    assert @bullet.migrated?
    assert_equal 'popped', @bullet.last_migration['action']
  end

  test 'pop! without date change does not mark migration' do
    @bullet.update!(pops_on: Date.current)

    @bullet.pop!(pops_on: Date.current)

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

  test 'complete! marks completed migration' do
    @bullet.bulletable.complete!

    @bullet.reload
    assert @bullet.migrated?
    assert_equal 'completed', @bullet.last_migration['action']
  end

  test 'acknowledge_migration! marks acknowledged migration' do
    @bullet.acknowledge_migration!

    @bullet.reload
    assert @bullet.migrated?
    assert_equal 'acknowledged', @bullet.last_migration['action']
  end

  test 'archive! marks archived migration' do
    @bullet.archive!

    assert @bullet.migrated?
    assert_equal 'archived', @bullet.last_migration['action']
  end
end
