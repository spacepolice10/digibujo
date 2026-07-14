# frozen_string_literal: true

require "test_helper"

class MentionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show redirects project mention to project path" do
    mention = create_project!(@user, name: "alpha")

    get mention_path(mention)

    assert_redirected_to project_path(mention)
  end

  test "show redirects person mention to person path" do
    mention = create_person!(@user, name: "ada")

    get mention_path(mention)

    assert_redirected_to person_path(mention)
  end

  test "show returns not found for another users mention" do
    mention = create_project!(users(:two), name: "secret")

    get mention_path(mention)

    assert_response :not_found
  end
end
