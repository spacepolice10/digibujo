# frozen_string_literal: true

require 'test_helper'

# rubocop:disable Style/ClassAndModuleChildren
class User::SettingsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.create_settings! unless @user.settings
    @settings = @user.settings
  end

  test 'SECTION_COLUMNS maps home sections to settings columns' do
    assert_equal 6, User::Settings::SECTION_COLUMNS.size
    assert_equal :logs_expanded,         User::Settings::SECTION_COLUMNS['logs']
    assert_equal :projects_expanded,     User::Settings::SECTION_COLUMNS['projects']
    assert_equal :collections_expanded,  User::Settings::SECTION_COLUMNS['collections']
    assert_equal :people_expanded,       User::Settings::SECTION_COLUMNS['people']
    assert_equal :trackers_expanded, User::Settings::SECTION_COLUMNS['trackers']
    assert_equal :published_expanded,    User::Settings::SECTION_COLUMNS['published']
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

  test 'APPEARANCES lists allowed background tints' do
    assert_equal %w[default warm cool nature cheese], User::Settings::APPEARANCES
  end

  test 'appearance must be a known preset' do
    @settings.appearance = 'warm'
    assert_predicate @settings, :valid?

    @settings.appearance = 'unknown'
    assert_not @settings.valid?
    assert_includes @settings.errors[:appearance], 'is not included in the list'
  end
end
# rubocop:enable Style/ClassAndModuleChildren
