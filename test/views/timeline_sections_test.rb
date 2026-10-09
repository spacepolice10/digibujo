# frozen_string_literal: true

require 'test_helper'

class TimelineSectionsTest < ActionView::TestCase
  setup do
    @user = users(:one)
    @timeline = Timeline.new(@user)
  end

  test 'renders each bullet through the bullet partial the caller supplies' do
    create_bullet!(@user, body: 'Anchor line', pops_on: Date.current)

    html = render partial: 'bullets/timeline_sections',
                  locals: { bullets: @user.bullets, timeline: @timeline, bullet_partial: 'bullets/current_bullet' }

    assert_select fragment(html), 'section#timeline_section_current_date .bullet--current', count: 1
  end

  test 'falls back to the bullet partial' do
    create_bullet!(@user, body: 'Plain line', pops_on: Date.current)

    html = render partial: 'bullets/timeline_sections', locals: { bullets: @user.bullets, timeline: @timeline }

    assert_select fragment(html), 'section#timeline_section_current_date > turbo-frame.bullet', count: 1
  end

  private

  def fragment(html)
    Nokogiri::HTML5.fragment(html)
  end
end
