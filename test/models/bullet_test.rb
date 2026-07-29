# frozen_string_literal: true

require 'test_helper'

class BulletTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    ensure_daylog!(@user)
  end

  test 'in_review includes daylog bullets in range with nil migrated_at' do
    in_range = create_bullet!(@user, bulletable: Task.new(body: 'In range'), pops_on: Date.current)
    create_bullet!(@user, bulletable: Task.new(body: 'Outside'), pops_on: Date.current - 10.days)
    migrated = create_bullet!(@user, bulletable: Task.new(body: 'Migrated'), pops_on: Date.current)
    migrated.update!(migrated_at: Time.current)

    collection = create_collection!(@user, name: 'Elsewhere')
    create_bullet!(@user, bucket: collection.bucket, bulletable: Task.new(body: 'Collected'), pops_on: nil)

    results = @user.bullets.in_review((Date.current - 6.days)..Date.current)

    assert_includes results, in_range
    assert_equal [in_range], results.to_a
  end

  test 'in_review excludes archived bullets' do
    bullet = create_bullet!(@user, bulletable: Task.new(body: 'Archived'), pops_on: Date.current)
    bullet.archive!

    assert_empty @user.bullets.in_review(Date.current..Date.current)
  end

  test 'accept_from_pending! moves bullet to daylog for today' do
    pending = Pending.provision!(@user)
    bullet = create_bullet!(@user, bucket: pending.bucket, bulletable: Note.new(body: 'Inbox'), pops_on: nil)

    bullet.accept_from_pending!

    assert_equal @user.daylog.bucket, bullet.reload.bucket
    assert_equal Date.current, bullet.pops_on
    assert bullet.rescheduled_migration?
  end

  test 'accept_from_pending! moves monthlylog today bullet to daylog' do
    monthlylog = create_monthlylog!(@user, name: 'This month')
    bullet = create_bullet!(
      @user,
      bucket: monthlylog.bucket,
      bulletable: Task.new(body: 'Planned today'),
      pops_on: Date.current
    )

    bullet.accept_from_pending!

    assert_equal @user.daylog.bucket, bullet.reload.bucket
    assert_equal Date.current, bullet.pops_on
  end

  test 'accept_from_pending! raises when bullet is not in the pending inbox' do
    bullet = create_bullet!(@user, bulletable: Note.new(body: 'Daylog note'))

    assert_raises(ArgumentError) { bullet.accept_from_pending! }
  end
end
