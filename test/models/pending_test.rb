# frozen_string_literal: true

require 'test_helper'

class PendingTest < ActiveSupport::TestCase
  test 'provision! creates pending and bucket' do
    user = User.create!(email_address: 'pending-provision@example.com')

    pending = Pending.provision!(user)

    assert_equal pending, user.reload.pending
    assert_not_nil pending.bucket
    assert_equal Onboarding::PENDING_NAME.downcase, pending.bucket.name
    assert_equal Onboarding::PENDING_ICON, pending.bucket.icon
  end

  test 'provision! is idempotent when pending already exists' do
    user = User.create!(email_address: 'pending-idempotent@example.com')
    first = Pending.provision!(user)

    assert_no_difference -> { Pending.where(user: user).count } do
      assert_equal first, Pending.provision!(user)
    end
  end

  test 'provision! attaches bucket when pending exists without one' do
    user = User.create!(email_address: 'pending-orphan@example.com')
    pending = user.create_pending!

    repaired = Pending.provision!(user)

    assert_equal pending, repaired
    assert_not_nil repaired.bucket
  end

  test 'pending_of returns active bullets from pending bucket' do
    user = users(:one)
    pending = Pending.provision!(user)

    capture = create_bullet!(user, bucket: pending.bucket, bulletable: Note.new, body: 'Capture', pops_on: nil)

    assert_includes Pending.pending_of(user), capture
  end

  test 'pending_of excludes archived bullets' do
    user = users(:one)
    pending = Pending.provision!(user)

    bullet = create_bullet!(user, bucket: pending.bucket, bulletable: Note.new, body: 'Archived me', pops_on: nil)
    bullet.archive!

    assert_empty Pending.pending_of(user)
  end

  test 'pending_number_of returns count of active pending bullets' do
    user = users(:one)
    pending = Pending.provision!(user)

    create_bullet!(user, bucket: pending.bucket, bulletable: Note.new, body: 'First', pops_on: nil)
    create_bullet!(user, bucket: pending.bucket, bulletable: Note.new, body: 'Second', pops_on: nil)

    assert_equal 2, Pending.pending_number_of(user)
  end
end
