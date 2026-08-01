# frozen_string_literal: true

require 'test_helper'

class BulletsHelperTest < ActionView::TestCase
  include BulletsHelper
  include IconHelper

  test 'bullet_type_config raises for unknown type' do
    assert_raises(ArgumentError, match: /Unknown bullet type: Invalid/) do
      bullet_type_config('Invalid')
    end
  end

  test 'bullet_type_config returns known type' do
    assert_equal 'square', bullet_type_config('Task')[:icon]
  end
end
