# frozen_string_literal: true

require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "create person with email and phone contacts" do
    assert_difference -> { Person.count }, 1 do
      post people_path, params: {
        person: {
          name: "Jordan",
          handles_attributes: {
            "0" => { kind: "email", data: "jordan@example.com" },
            "1" => { kind: "phone", data: "+1 555 0100" }
          }
        }
      }
    end

    person = Person.order(:id).last
    assert_redirected_to home_path
    assert_equal 2, person.handles.count
    assert_equal "jordan@example.com", person.handles.find_by(kind: :email).data
    assert_equal "+1 555 0100", person.handles.find_by(kind: :phone).data
  end

  test "update person contacts" do
    person = @user.people.create!(name: "jordan")
    email = person.handles.create!(kind: :email, data: "old@example.com")

    patch person_path(person), params: {
      person: {
        handles_attributes: {
          email.id.to_s => { id: email.id, kind: "email", data: "new@example.com" },
          (email.id + 1).to_s => { kind: "phone", data: "+1 555 0100" }
        }
      }
    }

    assert_redirected_to person_path(person)
    person.reload
    assert_equal "new@example.com", person.handles.find(email.id).data
    assert_equal "+1 555 0100", person.handles.find_by(kind: :phone).data
  end

  test "update clears contact when field is blank" do
    person = @user.people.create!(name: "jordan")
    email = person.handles.create!(kind: :email, data: "jordan@example.com")

    patch person_path(person), params: {
      person: {
        handles_attributes: {
          email.id.to_s => { id: email.id, kind: "email", data: "" }
        }
      }
    }

    assert_redirected_to person_path(person)
    assert_not person.handles.reload.exists?(email.id)
  end

  test "show renders clickable email and phone links" do
    person = @user.people.create!(name: "jordan")
    person.handles.create!(kind: :email, data: "jordan@example.com")
    person.handles.create!(kind: :phone, data: "+15550100")

    get person_path(person)

    assert_response :success
    assert_select "a.person--contact-link[href=?]", "mailto:jordan@example.com"
    assert_select "a.person--contact-link[href=?]", "tel:+15550100"
  end

  test "edit renders inline email and phone fields" do
    person = @user.people.create!(name: "jordan")
    person.handles.create!(kind: :email, data: "jordan@example.com")

    get edit_person_path(person)

    assert_response :success
    assert_select "form[action=?]", person_path(person)
    assert_select ".person--inline-field input[type=email][name^='person[handles_attributes]']"
    assert_select ".person--inline-field input[type=tel][name^='person[handles_attributes]']"
    assert_select "[data-controller='valid-email']"
    assert_select "[data-controller='valid-phone']"
    assert_select ".person--inline-field-icon[style*='--icon-mail']"
    assert_select ".person--inline-field-icon[style*='--icon-phone']"
  end
end
