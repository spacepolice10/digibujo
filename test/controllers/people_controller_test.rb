# frozen_string_literal: true

require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create person" do
    assert_difference -> { Mention.person.count }, 1 do
      post people_path, params: {
        mention: {
          name: "Jordan",
          colour: "teal"
        }
      }
    end

    person = Mention.person.order(:id).last
    assert_redirected_to home_path
    assert_equal "jordan", person.name
    assert_equal "teal", person.colour
  end

  test "show renders person bullets" do
    person = create_person!(@user, name: "jordan")

    get person_path(person)

    assert_response :success
    assert_select "h2.layout--surface-name", text: "jordan"
  end

  test "destroy person" do
    person = create_person!(@user, name: "jordan")

    assert_difference -> { Mention.person.count }, -1 do
      delete person_path(person)
    end

    assert_redirected_to people_path
  end
end
