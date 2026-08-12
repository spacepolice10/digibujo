# frozen_string_literal: true

require 'test_helper'

class OnboardingTest < ActiveSupport::TestCase
  test 'complete provisions daylog, monthlylog and pending' do
    user = User.create!(email_address: 'onboarding-loose@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert user.reload.onboarded?
    assert_not user.futures.any?
    assert_not_nil user.monthlylogs.any?
    assert_equal 1, user.monthlylogs.count
    assert_not_nil user.daylog
    assert_not_nil user.daylog.bucket
    assert_equal Onboarding::DAYLOG_ICON, user.daylog.bucket.icon
    assert_not_nil user.pending
    assert_not_nil user.pending.bucket
    assert_equal Onboarding::PENDING_ICON, user.pending.bucket.icon
    assert_not user.buckets.exists?(bucketable_type: 'Collection')
    assert_equal 0, user.bullets.count
  end

  test 'complete is idempotent' do
    user = User.create!(email_address: 'onboarding-idempotent@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert onboarding.complete

    assert user.reload.onboarded?
    assert_equal 0, Future.where(user: user).count
    assert_equal 1, user.monthlylogs.count
    assert_equal 1, Daylog.where(user: user).count
    assert_equal 1, Pending.where(user: user).count
    assert_equal 1, user.buckets.where(bucketable_type: 'Daylog').count
    assert_equal 1, user.buckets.where(bucketable_type: 'Monthlylog').count
    assert_equal 1, user.buckets.where(bucketable_type: 'Pending').count
    assert_equal 0, user.buckets.where(bucketable_type: 'Collection').count
    assert_equal 0, user.bullets.count
  end

  test 'complete with data seed provisions sample data' do
    user = User.create!(email_address: 'onboarding-seed@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete
    assert user.reload.onboarded?
    assert_equal 44, user.bullets.count
    assert_equal 15, user.bullets.where(bucket: user.daylog.bucket).count
    assert_equal 10, user.daylog.bullets.where(pops_on: Date.current).count
    assert_equal 5, user.daylog.bullets.where(pops_on: Date.yesterday).count
    assert_equal 10, user.bullets.where(bucket: user.monthlylogs.first.bucket).count
    assert_equal 7, user.bullets.where(bucket: user.futures.first.bucket).count
    assert_equal 12, user.bullets.joins(:bucket).where(buckets: { bucketable_type: 'Collection' }).count
    assert_equal %w[Event Note Task], user.bullets.distinct.order(:bulletable_type).pluck(:bulletable_type)

    collections = user.buckets.where(bucketable_type: 'Collection').order(:name)
    assert_equal 6, collections.count
    assert_equal Onboarding::COLLECTIONS.map { |attributes| attributes[:name].downcase }.sort,
                 collections.pluck(:name)
    assert_equal Onboarding::COLLECTIONS.map { |attributes| attributes[:icon] }.sort,
                 collections.pluck(:icon).sort
    assert_equal Onboarding::COLLECTIONS.map { |attributes| attributes[:colour] }.sort,
                 collections.pluck(:colour).sort
    assert(collections.all? { |bucket| bucket.bucketable.description.present? })

    rendered_bodies = user.bullets.map { |bullet| bullet.body.to_s }.join
    %w[<strong> <em> <ul>].each { |tag| assert_includes rendered_bodies, tag }
    assert_includes rendered_bodies, '<a href="https://aeon.co/"'
  end

  test 'sample bullets are active and monthly dates stay inside the spread' do
    user = User.create!(email_address: 'onboarding-seed-states@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete

    bullets = user.reload.bullets.includes(:archive, :bulletable)
    assert_equal bullets.count, bullets.active.count
    assert bullets.none?(&:archived?)
    assert bullets.none?(&:migrated?)
    assert bullets.none?(&:completed?)

    monthlylog = user.monthlylogs.first
    scheduled = monthlylog.bullets.scheduled
    assert_equal 4, scheduled.count
    assert(scheduled.all? { |bullet| bullet.pops_on.in?(monthlylog.period_from..monthlylog.period_to) })
    onboarding_bullet = monthlylog.bullets.find { |bullet| bullet.body_as_text.include?('monthly priority') }
    assert_equal user.created_at.to_date, onboarding_bullet.pops_on

    triage = Daylog::Triage.new(user.reload, date: Date.current)
    assert_equal 5, triage.yesterday_bullets.count
    assert(triage.yesterday_bullets.all? { |bullet| bullet.pops_on == Date.yesterday })
    assert_includes triage.monthlylog_bullets.map(&:body_as_text),
                    'Move this monthly priority to Today during triage'
    assert_includes triage.yesterday_bullets.map(&:body_as_text),
                    'Drag this bullet to Today to keep working on it'
  end

  test 'complete with data seed is idempotent' do
    user = User.create!(email_address: 'onboarding-seed-idempotent@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete
    bullets_after_first = user.reload.bullets.count
    collections_after_first = user.buckets.where(bucketable_type: 'Collection').count
    assert onboarding.complete

    assert_equal bullets_after_first, user.reload.bullets.count
    assert_equal collections_after_first, user.buckets.where(bucketable_type: 'Collection').count
    assert_equal 1, user.futures.count
  end

  test 'data_seed? normalizes string values' do
    assert Onboarding.new(user: User.new, data_seed: 'true').data_seed?
    assert Onboarding.new(user: User.new, data_seed: '1').data_seed?
    assert Onboarding.new(user: User.new, data_seed: true).data_seed?
    assert_not Onboarding.new(user: User.new, data_seed: 'false').data_seed?
    assert_not Onboarding.new(user: User.new, data_seed: nil).data_seed?
  end
end
