# frozen_string_literal: true

require 'test_helper'

# rubocop:disable Style/ClassAndModuleChildren
class User::SettingsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.create_settings! unless @user.settings
    @settings = @user.settings
  end

  test 'SECTION_COLUMNS has 4 entries mapping sections to columns' do
    assert_equal 4, User::Settings::SECTION_COLUMNS.size
    assert_equal :logs_expanded,        User::Settings::SECTION_COLUMNS['logs']
    assert_equal :projects_expanded,    User::Settings::SECTION_COLUMNS['projects']
    assert_equal :collections_expanded, User::Settings::SECTION_COLUMNS['collections']
    assert_equal :spreads_expanded,     User::Settings::SECTION_COLUMNS['spreads']
  end

  test 'SECTION_COLUMNS values correspond to real columns on user_settings' do
    columns = User::Settings.column_names
    User::Settings::SECTION_COLUMNS.each_value do |column|
      assert_includes columns, column.to_s,
        "SECTION_COLUMNS references #{column.inspect} which is not a column on user_settings"
    end
  end

  test 'SECTIONS matches SECTION_COLUMNS keys' do
    assert_equal User::Settings::SECTION_COLUMNS.keys, User::Settings::SECTIONS
  end

  test 'belongs to user' do
    assert_equal @user, @settings.user
  end
end
# rubocop:enable Style/ClassAndModuleChildren
