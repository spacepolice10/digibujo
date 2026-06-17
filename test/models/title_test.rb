# frozen_string_literal: true

require 'test_helper'

class TitleTest < ActiveSupport::TestCase
  test 'validates text presence' do
    title = Title.new(text: '')
    assert_not title.valid?
    assert_includes title.errors[:text], "can't be blank"
  end

  test 'is valid with text' do
    title = Title.new(text: 'My Heading')
    assert title.valid?
  end

  test 'name returns text' do
    title = Title.new(text: 'Hello')
    assert_equal 'Hello', title.name
  end

  test 'temporal? is false' do
    title = Title.new(text: 'X')
    assert_not title.temporal?
  end

  test 'completable? is false' do
    title = Title.new(text: 'X')
    assert_not title.completable?
  end
end
