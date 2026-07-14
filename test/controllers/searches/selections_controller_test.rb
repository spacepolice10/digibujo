# frozen_string_literal: true

require "test_helper"

module Searches
  class SelectionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      sign_in_as @user
      @project = create_project!(@user, name: "alpha")
    end

    test "create records a selection and returns no content" do
      assert_difference -> { @user.search_selections.count }, 1 do
        post search_selection_path,
             params: { searchable_type: "Mention", searchable_id: @project.id, query: "alp" },
             as: :json
      end

      assert_response :no_content

      selection = @user.search_selections.sole
      assert_equal @project, selection.searchable
      assert_equal "alp", selection.query
    end

    test "create rejects unknown searchable type" do
      post search_selection_path,
           params: { searchable_type: "User", searchable_id: @user.id },
           as: :json

      assert_response :not_found
      assert_empty @user.search_selections
    end

    test "create rejects another users entity" do
      other_project = create_project!(@other_user, name: "secret")

      post search_selection_path,
           params: { searchable_type: "Mention", searchable_id: other_project.id },
           as: :json

      assert_response :not_found
      assert_empty @user.search_selections
    end
  end
end
