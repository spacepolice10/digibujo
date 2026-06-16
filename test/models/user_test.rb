# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'downcases and strips email_address' do
    user = User.new(email_address: ' DOWNCASED@EXAMPLE.COM ')
    assert_equal('downcased@example.com', user.email_address)
  end

  test 'has_one :settings' do
    assert_respond_to users(:one), :settings
  end

  test 'creating a user auto-creates settings' do
    user = User.create!(email_address: 'new-settings@example.com')
    assert_not_nil user.settings
    assert_predicate user.settings, :persisted?
  end
end
