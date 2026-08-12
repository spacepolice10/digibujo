# frozen_string_literal: true

require 'test_helper'

class OnboardingSampleOrderTest < ActiveSupport::TestCase
  test 'guided actions start at the bottom of each chat-style list' do
    user = User.create!(email_address: 'onboarding-seed-order@example.com')

    assert Onboarding.new(user: user, data_seed: 'true').complete

    assert_equal 'Write your first bullet',
                 user.daylog.bullets.where(pops_on: Date.current).chronologically.last.body_as_text
    assert_equal 'Create a bullet for something you want to do this month',
                 user.monthlylogs.first.bullets.unscheduled.chronologically.last.body_as_text
    assert_equal 'Add a goal for the next six months',
                 user.futures.first.bullets.unscheduled.chronologically.last.body_as_text
    assert_equal 'Welcome to triage — decide what still deserves your attention',
                 Daylog::Triage.new(user, date: Date.current).yesterday_bullets.last.body_as_text
  end
end
