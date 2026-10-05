# frozen_string_literal: true

require 'test_helper'

class TimelineTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 9, 30)
  end

  test 'sections split recent days and then widen' do
    assert_equal 'current_date', section(0).key
    assert_equal 'yesterday', section(1).key
    assert_equal 'this-week', section(2).key
    assert_equal 'This week', section(2).label
    assert_equal 'this-week', section(6).key
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

  test 'a future day gets its own section' do
    section = Timeline.section_of(Date.current + 1)
    assert_equal (Date.current + 1).iso8601, section.key
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

    assert_equal [past, due, filed].sort_by(&:id), timeline.filtered.sort_by(&:id)
    assert_not_includes timeline.filtered, later
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
    Timeline.section_of(Date.current - age)
  end
end
