# frozen_string_literal: true

require 'test_helper'

class OnboardingTest < ActiveSupport::TestCase
  test 'complete marks the user onboarded without content' do
    user = User.create!(email_address: 'onboarding-loose@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert user.reload.onboarded?
    assert_equal 0, user.collections.count
    assert_equal 0, user.bullets.count
  end

  test 'complete is idempotent' do
    user = User.create!(email_address: 'onboarding-idempotent@example.com')
    onboarding = Onboarding.new(user: user)

    assert onboarding.complete
    assert onboarding.complete

    assert user.reload.onboarded?
    assert_equal 0, user.collections.count
    assert_equal 0, user.bullets.count
  end

  test 'complete with data seed provisions sample data' do
    user = User.create!(email_address: 'onboarding-seed@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete
    assert user.reload.onboarded?
    assert_equal 25, user.bullets.count
    assert_equal 7, user.timeline.bullets.where(pops_on: Date.current).count
    assert_equal 3, user.timeline.bullets.where(pops_on: Date.yesterday).count
    assert_equal 3, user.timeline.upcoming.count
    assert_equal 12, user.bullets.where.not(collection_id: nil).count
    assert_equal %w[Text], user.bullets.distinct.pluck(:bulletable_type)

    collections = user.collections.order(:name)
    assert_equal 6, collections.count
    assert_equal Onboarding::COLLECTIONS.map { |attributes| attributes[:name].downcase }.sort,
                 collections.pluck(:name)
    assert_equal Onboarding::COLLECTIONS.map { |attributes| attributes[:icon] }.sort,
                 collections.pluck(:icon).sort
    assert_equal Onboarding::COLLECTIONS.map { |attributes| attributes[:colour] }.sort,
                 collections.pluck(:colour).sort
    assert(collections.all? { |collection| collection.description.present? })

    rendered_bodies = user.bullets.map { |bullet| bullet.body.to_s }.join
    %w[<strong> <em> <ul>].each { |tag| assert_includes rendered_bodies, tag }
    assert_includes rendered_bodies, '<a href="https://aeon.co/"'
  end

  test 'sample bullets are active, open and upcoming ones are in the future' do
    user = User.create!(email_address: 'onboarding-seed-states@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete

    bullets = user.reload.bullets.includes(:archive, :bulletable)
    assert_equal bullets.count, bullets.active.count
    assert bullets.none?(&:archived?)
    assert bullets.none?(&:done?)
    assert(user.timeline.upcoming.all? { |bullet| bullet.pops_on > Date.current })
  end

  test 'complete with data seed is idempotent' do
    user = User.create!(email_address: 'onboarding-seed-idempotent@example.com')
    onboarding = Onboarding.new(user: user, data_seed: 'true')

    assert onboarding.complete
    bullets_after_first = user.reload.bullets.count
    collections_after_first = user.collections.count
    assert onboarding.complete

    assert_equal bullets_after_first, user.reload.bullets.count
    assert_equal collections_after_first, user.collections.count
  end

  test 'data_seed? normalizes string values' do
    assert Onboarding.new(user: User.new, data_seed: 'true').data_seed?
    assert Onboarding.new(user: User.new, data_seed: '1').data_seed?
    assert Onboarding.new(user: User.new, data_seed: true).data_seed?
    assert_not Onboarding.new(user: User.new, data_seed: 'false').data_seed?
    assert_not Onboarding.new(user: User.new, data_seed: nil).data_seed?
  end
end
