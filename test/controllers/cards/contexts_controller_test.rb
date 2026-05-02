# frozen_string_literal: true

require "test_helper"

class Bullets::ContextsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "returns matching bullets for picker" do
    target = @user.bullets.create!(bulletable: Note.create!, content: '<a href="https://example.com/kickoff">Kickoff docs</a>')
    @user.bullets.create!(bulletable: Task.create!, content: "Another item")

    get "/bullets/contexts.json", params: { q: "example.com/kickoff" }

    assert_response :success
    data = JSON.parse(response.body)
    assert_equal 1, data["bullets"].length
    assert_equal target.id, data["bullets"][0]["id"]
  end

  test "exclude_id removes current card from results" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Current card")

    get "/bullets/contexts.json", params: { q: "current", exclude_id: card.id }

    assert_response :success
    data = JSON.parse(response.body)
    assert_equal [], data["bullets"]
  end
end
