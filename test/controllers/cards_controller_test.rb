# frozen_string_literal: true

require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "timeline cards are not draggable" do
    @user.cards.create!(cardable: Task.create!, content: "Copy me")
    get cards_path
    assert_select ".card[draggable='true']", count: 0
    assert_select ".card[data-controller~='card-drag']", count: 0
    assert_select ".card[data-card-drag-id-value]", count: 0
    assert_select ".card-body[data-controller~='card-link']"
  end

  test "create links an existing context card only" do
    context_card = @user.cards.create!(cardable: Note.create!, content: "Customer notes")

    assert_difference("Card.count", 1) do
      post cards_path, params: {
        card: {
          cardable_type: "task",
          content: "Task with context",
          context_card_id: context_card.id
        }
      }
    end

    created_card = @user.cards.order(:created_at).last
    assert_equal context_card.id, created_card.context_card_id
  end
end
