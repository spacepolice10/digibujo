# frozen_string_literal: true

require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create person with nested handles" do
    assert_difference -> { Person.count }, 1 do
      post people_path, params: {
        person: {
          name: "Jordan",
          handles_attributes: {
            "0" => { kind: "email", data: "jordan@example.com" },
            "1" => { kind: "phone", data: "+1 555 0100" },
            "2" => { kind: "handle", platform: "instagram", data: "jordan" }
          }
        }
      }
    end

    person = Person.order(:id).last
    assert_redirected_to home_path
    assert_equal 3, person.handles.count
    assert_equal "jordan@example.com", person.handles.find_by(kind: :email).data
  end

  test "create allows duplicate phone numbers" do
    post people_path, params: {
      person: {
        name: "Jordan",
        handles_attributes: {
          "0" => { kind: "phone", data: "+1 111" },
          "1" => { kind: "phone", data: "+1 222" }
        }
      }
    }

    person = Person.order(:id).last
    assert_equal 2, person.handles.phone.count
  end

  test "update person handles" do
    person = @user.people.create!(name: "jordan")
    email = person.handles.create!(kind: :email, data: "old@example.com")

    patch person_path(person), params: {
      person: {
        handles_attributes: {
          "0" => { id: email.id, kind: "email", data: "new@example.com" },
          "1" => { kind: "handle", platform: "github", data: "jordan" }
        }
      }
    }

    assert_redirected_to person_path(person)
    person.reload
    assert_equal "new@example.com", person.handles.find(email.id).data
    assert_equal "github", person.handles.find_by(kind: :handle).platform
  end

  test "show renders clickable email and phone links" do
    person = @user.people.create!(name: "jordan")
    person.handles.create!(kind: :email, data: "jordan@example.com")
    person.handles.create!(kind: :phone, data: "+15550100")

    get person_path(person)

    assert_response :success
    assert_select "a.person--handle-link[href=?]", "mailto:jordan@example.com"
    assert_select "a.person--handle-link[href=?]", "tel:+15550100"
  end

  test "edit renders handle form" do
    person = @user.people.create!(name: "jordan")
    person.handles.create!(kind: :email, data: "jordan@example.com")

    get edit_person_path(person)

    assert_response :success
    assert_select "form[action=?]", person_path(person)
    assert_select "input[name=?]", "person[handles_attributes][0][data]"
  end
end
