# frozen_string_literal: true

require 'test_helper'

class DaylogTest < ActiveSupport::TestCase
  test 'provision! creates daylog and bucket' do
    user = User.create!(email_address: 'daylog-provision@example.com')

    daylog = Daylog.provision!(user)

    assert_equal daylog, user.reload.daylog
    assert_not_nil daylog.bucket
    assert_equal Onboarding::DAYLOG_NAME.downcase, daylog.bucket.name
    assert_equal Onboarding::DAYLOG_ICON, daylog.bucket.icon
    assert_not user.buckets.exists?(bucketable_type: 'Collection', name: 'loose notes')
  end

  test 'provision! is idempotent when daylog already exists' do
    user = User.create!(email_address: 'daylog-idempotent@example.com')
    first = Daylog.provision!(user)

    assert_no_difference -> { Daylog.where(user: user).count } do
      assert_equal first, Daylog.provision!(user)
    end
  end

  test 'provision! attaches bucket when daylog exists without one' do
    user = User.create!(email_address: 'daylog-orphan@example.com')
    daylog = user.create_daylog!

    repaired = Daylog.provision!(user)

    assert_equal daylog, repaired
    assert_not_nil repaired.bucket
  end

end
