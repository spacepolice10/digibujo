# frozen_string_literal: true

require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "timeline cards have card-drag controller attributes" do
    draft = Draft.create!
    @user.cards.create!(cardable: draft, content: "Drag me")
    get cards_path
    assert_select ".card[data-controller~='card-drag']"
    assert_select ".card[data-card-drag-id-value]"
  end
end
