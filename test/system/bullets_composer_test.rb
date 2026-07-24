# frozen_string_literal: true

require 'application_system_test_case'

class BulletsComposerSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    Onboarding.new(user: @user).complete
    @bucket = @user.reload.daylog.bucket
    sign_in_as(@user)
  end

  test 'mod-enter submits the composer and returns to the daylog' do
    visit new_bullet_path(
      bulletable_type: 'Task',
      pops_on: Date.current,
      bucket_id: @bucket.id
    )

    body = find('textarea.bullets-form--body')
    body.send_keys('Buy oat milk')
    body.send_keys([modifier_key, :enter])

    assert_current_path daylog_path(date: Date.current.iso8601)
    assert_text 'Buy oat milk'
    assert Task.joins(:bullet).where(body: 'Buy oat milk', bullets: { user_id: @user.id }).exists?
  end

  private

  def modifier_key
    RUBY_PLATFORM.match?(/darwin/i) ? :meta : :control
  end
end
