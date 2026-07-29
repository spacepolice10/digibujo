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

  test 'inbox_for includes pending and monthlylog bullets for today' do
    user = users(:one)
    ensure_daylog!(user)
    pending = Pending.provision!(user)
    monthlylog = create_monthlylog!(user, name: 'This month')

    capture = create_bullet!(user, bucket: pending.bucket, bulletable: Note.new(body: 'Capture'), pops_on: nil)
    today = create_bullet!(
      user,
      bucket: monthlylog.bucket,
      bulletable: Task.new(body: 'Today cell'),
      pops_on: Date.current
    )
    create_bullet!(
      user,
      bucket: monthlylog.bucket,
      bulletable: Task.new(body: 'Other day'),
      pops_on: Date.current + 2.days
    )

    inbox = Pending.inbox_for(user)

    assert_includes inbox, capture
    assert_includes inbox, today
    assert_equal 2, inbox.count
  end
end
