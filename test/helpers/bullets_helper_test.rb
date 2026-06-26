# frozen_string_literal: true

require 'test_helper'

class BulletsHelperTest < ActionView::TestCase
  include BulletsHelper

  setup do
    @user = users(:one)
    @bullet = @user.bullets.create!(bulletable: Task.create!, body: 'Task', pops_on: Date.current)
  end

  test 'migration_hint describes popped move between days' do
    from = Date.current
    to = Date.current + 2.days
    @bullet.update!(pops_on: to)
    @bullet.mark_migration!(action: 'popped', from_pops_on: from, to_pops_on: to)

    assert_includes migration_hint(@bullet), from.strftime('%a, %b %-d')
    assert_includes migration_hint(@bullet), to.strftime('%a, %b %-d')
    assert_match(/Moved — rescheduled/, migration_hint(@bullet))
  end

  test 'migration_hint describes collection' do
    @bullet.mark_migration!(action: 'collected', bucket_id: 1, bucket_name: 'Reading list')

    assert_equal 'Collected — moved into Reading list.', migration_hint(@bullet)
  end

  test 'migration_hint describes completion' do
    @bullet.mark_migration!(action: 'completed', pops_on: Date.current)

    assert_match(/Completed/, migration_hint(@bullet))
  end

  test 'migration_hint describes archive' do
    @bullet.mark_migration!(action: 'archived', pops_on: Date.current)

    assert_match(/Archived — removed from/, migration_hint(@bullet))
  end

  test 'migration_hint describes acknowledged review' do
    @bullet.mark_migration!(action: 'acknowledged', pops_on: Date.current)

    assert_match(/Reviewed — kept on/, migration_hint(@bullet))
  end

  test 'migration_hint is nil when not migrated' do
    assert_nil migration_hint(@bullet)
  end
end
