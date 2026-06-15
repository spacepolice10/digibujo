# frozen_string_literal: true

require 'test_helper'

class TimelineHelperTest < ActionView::TestCase
  include TimelineHelper

  test 'prev_date and next_date step one day' do
    date = Date.new(2026, 4, 15)
    assert_equal Date.new(2026, 4, 14), prev_date(date)
    assert_equal Date.new(2026, 4, 16), next_date(date)
  end

  test 'prev_date_href builds previous day path' do
    date = Date.new(2026, 4, 15)
    assert_equal daylog_path(date: '2026-04-14'), prev_date_href(date)
  end

  test 'next_date_href builds next day path' do
    date = Date.new(2026, 4, 15)
    assert_equal daylog_path(date: '2026-04-16'), next_date_href(date)
  end
end
