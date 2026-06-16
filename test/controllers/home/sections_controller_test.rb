# frozen_string_literal: true

require 'test_helper'

module Home
  class SectionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @user.create_settings! unless @user.settings
      sign_in_as @user
    end

    test 'update persists open state for allowed section' do
      patch home_section_path('projects'), params: { open: 'false' }
      assert_response :ok
      assert_equal false, @user.reload.settings.projects_open?
    end

    test 'update persists open=true from form data' do
      patch home_section_path('projects'), params: { open: 'true' }
      assert_response :ok
      assert_equal true, @user.reload.settings.projects_open?
    end

    test 'update rejects unknown section' do
      patch home_section_path('unknown'), params: { open: false }
      assert_response :unprocessable_entity
    end

    test 'update works when user has no settings row' do
      @user.settings.destroy!

      patch home_section_path('projects'), params: { open: false }

      assert_response :ok
      assert_equal false, @user.reload.settings.projects_open?
    end
  end
end
