# frozen_string_literal: true

require 'test_helper'

# rubocop:disable Style/ClassAndModuleChildren
class User::SettingsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.create_settings! unless @user.settings
    @settings = @user.settings
  end

  test 'SECTIONS lists the known section keys' do
    assert_equal %w[logs projects collections spreads], User::Settings::SECTIONS
  end

  test 'section_open? returns the column value for a known section' do
    @settings.projects_open = false
    assert_equal false, @settings.section_open?(:projects)
  end

  test 'section_open? returns true for an unknown section' do
    assert_equal true, @settings.section_open?(:unknown)
  end

  test 'set_section_open updates the underlying column' do
    @settings.set_section_open(:logs, false)
    assert_equal false, @settings.reload.logs_open
  end

  test 'set_section_open raises for an unknown section' do
    assert_raises(NoMethodError) do
      @settings.set_section_open(:unknown, false)
    end
  end

  test 'belongs to user' do
    assert_equal @user, @settings.user
  end
end
# rubocop:enable Style/ClassAndModuleChildren
