# frozen_string_literal: true

require 'test_helper'

class TimelineTest < ActiveSupport::TestCase
  setup do
    @today = Date.new(2026, 9, 30)
  end

  test 'sections split recent days and then widen' do
    assert_equal 'today', section(0).key
    assert_equal 'yesterday', section(1).key
    assert_equal '2026-09-28', section(2).key
    assert_equal 'Monday, Sep 28', section(2).label
    assert_equal '2026-09-24', section(6).key
    assert_equal 'last-week', section(7).key
    assert_equal 'last-week', section(13).key
    assert_equal 'last-month', section(14).key
    assert_equal 'last-month', section(30).key
    assert_equal 'last-3-months', section(31).key
    assert_equal 'last-3-months', section(90).key
    assert_equal 'last-year', section(91).key
    assert_equal 'last-year', section(365).key
    assert_equal 'year-2025', section(366).key
  end

  test 'a day from today onwards belongs to today' do
    assert_equal 'today', Timeline.section_for(@today + 1, today: @today).key
  end

  test 'bullets are due, not upcoming, up to today' do
    user = users(:one)
    due = create_bullet!(user, body: 'Due', pops_on: Date.current)
    past = create_bullet!(user, body: 'Past', pops_on: Date.current - 20)
    later = create_bullet!(user, body: 'Later', pops_on: Date.current + 2)
    filed = create_bullet!(user, body: 'Filed', collection: create_collection!(user, name: 'work'))
    archived = create_bullet!(user, body: 'Archived')
    archived.archive!

    timeline = Timeline.new(user)

    assert_equal [past, due, filed].reject { |bullet| bullet == filed }.sort_by(&:id), timeline.bullets.sort_by(&:id)
    assert_equal [later], timeline.upcoming.to_a
  end

  test 'last_page and page_before walk back through the feed' do
    user = users(:one)
    bullets = Array.new(5) { |index| create_bullet!(user, body: "Day #{index}", pops_on: Date.current - (4 - index)) }
    timeline = Timeline.new(user)

    assert_equal bullets.map(&:id), timeline.last_page.map(&:id)
    assert_equal bullets.first(2).map(&:id), timeline.page_before(bullets[2]).map(&:id)
  end

  private

  def section(age)
    Timeline.section_for(@today - age, today: @today)
  end
end
