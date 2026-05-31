# frozen_string_literal: true

require "test_helper"

class Projects::SuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index renders current user project suggestions as picker rows" do
    project = create_project!(@user, name: "alpha", icon: "book")
    other_user_project = create_project!(users(:two), name: "other")

    get project_suggestions_path

    assert_response :success
    assert_select "turbo-frame#project_suggestions"
    assert_select "[data-bucket-id=?]", project.bucket.id.to_s
    assert_select ".bucket--list-item-name", text: project.name
    assert_no_match other_user_project.name, response.body
  end

  test "index filters html project suggestions by query" do
    create_project!(@user, name: "alpha")
    create_project!(@user, name: "beta")

    get project_suggestions_path, params: { q: "alp" }

    assert_response :success
    assert_match "alpha", response.body
    assert_no_match "beta", response.body
  end

  test "index uses requested turbo frame id" do
    project = create_project!(@user, name: "alpha")

    get project_suggestions_path, params: { frame_id: "custom_project_suggestions" }

    assert_response :success
    assert_select "turbo-frame#custom_project_suggestions"
    assert_select "[data-bucket-id=?]", project.bucket.id.to_s
  end
end
