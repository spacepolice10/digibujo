# frozen_string_literal: true

require 'test_helper'

class BundleTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @collection = create_collection!(@user, name: 'Parent')
  end

  test 'requires a collection' do
    bundle = Bundle.new(user: @user)

    assert_not bundle.valid?
    assert_includes bundle.errors[:collection], "can't be blank"
  end

  test 'is valid with a collection' do
    bundle = Bundle.new(user: @user, collection: @collection)

    assert bundle.valid?
  end
end
