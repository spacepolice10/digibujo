# frozen_string_literal: true

require 'test_helper'

module Projects
  class SuggestionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test 'index renders current user project suggestions as lexxy prompt items' do
      project = create_project!(@user, name: 'alpha')
      other_user_project = create_project!(users(:two), name: 'other')

      get project_suggestions_path

      assert_response :success
      assert_select 'lexxy-prompt-item[search=?]', project.name
      assert_select '.utilities--line-clamp-1', text: project.name
      assert_no_match other_user_project.name, response.body
    end

    test 'index filters project suggestions by lexxy filter param' do
      create_project!(@user, name: 'alpha')
      create_project!(@user, name: 'beta')

      get project_suggestions_path, params: { filter: 'alp' }

      assert_response :success
      assert_match 'alpha', response.body
      assert_no_match 'beta', response.body
    end
  end
end
