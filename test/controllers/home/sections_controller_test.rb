# frozen_string_literal: true

require 'test_helper'

module Home
  class SectionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @user.create_settings! unless @user.settings
      sign_in_as @user
    end

    test 'expand persists true for a known section' do
      post home_expand_section_path('projects')
      assert_response :ok
      assert_equal true, @user.reload.settings.projects_expanded?
    end

    test 'collapse persists false for a known section' do
      post home_collapse_section_path('projects')
      assert_response :ok
      assert_equal false, @user.reload.settings.projects_expanded?
    end

    test 'expand rejects an unknown section' do
      post home_expand_section_path('unknown')
      assert_response :unprocessable_entity
    end

    test 'collapse rejects an unknown section' do
      post home_collapse_section_path('unknown')
      assert_response :unprocessable_entity
    end

    test 'expand creates the settings row when missing' do
      @user.settings.destroy!

      post home_expand_section_path('projects')

      assert_response :ok
      assert_equal true, @user.reload.settings.projects_expanded?
    end

    test 'collapse creates the settings row when missing' do
      @user.settings.destroy!

      post home_collapse_section_path('projects')

      assert_response :ok
      assert_equal false, @user.reload.settings.projects_expanded?
    end
  end
end
