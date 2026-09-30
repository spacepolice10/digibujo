# frozen_string_literal: true

require 'test_helper'

class OnboardingSampleOrderTest < ActiveSupport::TestCase
  test 'guided action starts at the bottom of the timeline' do
    user = User.create!(email_address: 'onboarding-seed-order@example.com')

    assert Onboarding.new(user: user, data_seed: 'true').complete

    assert_equal 'Write your first bullet',
                 user.timeline.bullets.by_day.last.body_as_text
  end
end
