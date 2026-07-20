# frozen_string_literal: true

require 'test_helper'

class EventTest < ActiveSupport::TestCase
  test 'stores date range on event' do
    event = Event.create!(starts_date: Date.current, ends_date: Date.current + 2, body: 'Conference')
    bullet = create_bullet!(users(:one),bulletable: event)

    assert_equal Date.current, bullet.starts_date
    assert_equal Date.current + 2, bullet.ends_date
  end

  test 'permitted bullet attributes include date fields' do
    assert_equal %i[id body starts_date ends_date], Event.permitted_bullet_attributes
  end
end
