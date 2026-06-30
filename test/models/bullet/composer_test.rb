# frozen_string_literal: true

require 'test_helper'

class Bullet::ComposerTest < ActiveSupport::TestCase
  test 'composer_partial_of resolves type folder partials' do
    assert_equal 'notes/composer', Bullet.composer_partial_of('Note')
    assert_equal 'tasks/composer', Bullet.composer_partial_of('Task')
    assert_equal 'events/composer', Bullet.composer_partial_of('Event')
    assert_equal 'voices/composer', Bullet.composer_partial_of('Voice')
  end
end
