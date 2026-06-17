# frozen_string_literal: true

require 'test_helper'

class TitleTest < ActiveSupport::TestCase
  test 'is valid without text' do
    title = Title.new
    assert title.valid?
  end

  test 'name returns body text from bullet' do
    title = Title.create!
    bullet = Bullet.create!(user: users(:one), bulletable: title, body: 'Hello')
    assert_equal 'Hello', bullet.name
  end

  test 'temporal? is false' do
    title = Title.new
    assert_not title.temporal?
  end

  test 'completable? is false' do
    title = Title.new
    assert_not title.completable?
  end
end
