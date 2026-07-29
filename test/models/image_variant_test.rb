# frozen_string_literal: true

require 'test_helper'

class ImageVariantTest < ActiveSupport::TestCase
  test 'exposes named transformations for display sizes' do
    assert_equal({ resize_to_limit: [ 64, 64 ] }, ImageVariant[:thumb])
    assert_equal({ resize_to_limit: [ 800, 800 ] }, ImageVariant[:preview])
    assert_equal({ resize_to_limit: [ 1600, 1600 ] }, ImageVariant[:display])
    assert_equal({ resize_to_fill: [ 1200, 200 ] }, ImageVariant[:header])
    assert_equal({ resize_to_fill: [ 720, 180 ] }, ImageVariant[:band])
  end

  test 'rejects unknown variant names' do
    assert_raises(KeyError) { ImageVariant[:missing] }
  end
end
