# frozen_string_literal: true

require 'test_helper'

class HookTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding.new(user: @user).complete
  end

  test 'generate code on create' do
    hook = @user.hooks.create!(name: 'Zapier')

    assert hook.code.start_with?('hk_')
    assert_equal hook.code_prefix, hook.code.first(8)
    assert_equal Hook.digest(hook.code), hook.code_digest
  end

  test 'authenticate finds active hook by code' do
    hook = @user.hooks.create!(name: 'Zapier')
    raw = hook.code

    assert_equal hook, Hook.authenticate(raw)
    hook.update!(active: false)
    assert_nil Hook.authenticate(raw)
  end

  test 'create_pending_bullet! writes into pending bucket' do
    hook = @user.hooks.create!(name: 'Zapier')

    bullet = hook.create_pending_bullet!(
      author_name: 'Zapier',
      bulletable_type: 'Note',
      body: 'From outside'
    )

    assert bullet.pending?
    assert_equal 'Zapier', bullet.author_name
    assert_equal 'From outside', bullet.body_as_text
  end
end
