# frozen_string_literal: true

require "test_helper"

class Cards::ContextsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "returns matching cards for picker" do
    target = @user.cards.create!(cardable: Note.create!, content: '<a href="https://example.com/kickoff">Kickoff docs</a>')
    @user.cards.create!(cardable: Task.create!, content: "Another item")

    get "/cards/contexts.json", params: { q: "example.com/kickoff" }

    assert_response :success
    data = JSON.parse(response.body)
    assert_equal 1, data["cards"].length
    assert_equal target.id, data["cards"][0]["id"]
  end

  test "exclude_id removes current card from results" do
    card = @user.cards.create!(cardable: Task.create!, content: "Current card")

    get "/cards/contexts.json", params: { q: "current", exclude_id: card.id }

    assert_response :success
    data = JSON.parse(response.body)
    assert_equal [], data["cards"]
  end
end
