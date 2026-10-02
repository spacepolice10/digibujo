# frozen_string_literal: true

require 'test_helper'

class Bullet::FilterTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @today = Date.new(2026, 9, 30)
  end

  test 'default filter is due through today' do
    filter = Bullet::Filter.from_params({}, user: @user, today: @today)

    assert filter.empty?
    assert_equal 'Daylog', filter.label
    assert filter.includes_today?

    due = create_bullet!(@user, body: 'Due', pops_on: @today)
    later = create_bullet!(@user, body: 'Later', pops_on: @today + 1)

    ids = filter.apply(@user.bullets.active).pluck(:id)
    assert_includes ids, due.id
    assert_not_includes ids, later.id
  end

  test 'from filters upcoming bullets' do
    filter = Bullet::Filter.from_params({ from: (@today + 1).iso8601 }, user: @user, today: @today)

    assert_equal 'Upcoming', filter.label
    assert_not filter.includes_today?

    due = create_bullet!(@user, body: 'Due', pops_on: @today)
    later = create_bullet!(@user, body: 'Later', pops_on: @today + 1)

    ids = filter.apply(@user.bullets.active).pluck(:id)
    assert_not_includes ids, due.id
    assert_includes ids, later.id
  end

  test 'collection filter tags bullets' do
    collection = create_collection!(@user, name: 'Loose notes')
    tagged = create_bullet!(@user, body: 'Tagged', collection: collection, pops_on: @today)
    plain = create_bullet!(@user, body: 'Plain', pops_on: @today)

    filter = Bullet::Filter.from_params({ collection: 'loose notes' }, user: @user, today: @today)
    ids = filter.apply(@user.bullets.active).pluck(:id)

    assert_equal collection, filter.collection
    assert_includes ids, tagged.id
    assert_not_includes ids, plain.id
  end

  test 'unknown collection raises' do
    assert_raises(Bullet::Filter::Error) do
      Bullet::Filter.from_params({ collection: 'missing' }, user: @user, today: @today)
    end
  end

  test 'inverted date range raises' do
    assert_raises(Bullet::Filter::Error) do
      Bullet::Filter.from_params({ from: '2026-10-02', to: '2026-09-01' }, user: @user, today: @today)
    end
  end
end
