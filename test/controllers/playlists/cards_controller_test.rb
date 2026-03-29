# frozen_string_literal: true

require 'test_helper'

module Playlists
  class CardsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @playlist = @user.playlists.create!
      @card = create_card(@user)
    end

    test 'create adds card to playlist' do
      assert_difference 'PlaylistCard.count', 1 do
        post playlist_cards_path(@playlist), params: { card_id: @card.id }
      end
      assert_redirected_to playlist_path(@playlist)
    end

    test 'create assigns incrementing position' do
      post playlist_cards_path(@playlist), params: { card_id: @card.id }
      card_b = create_card(@user)
      post playlist_cards_path(@playlist), params: { card_id: card_b.id }

      positions = @playlist.playlist_cards.reload.pluck(:position)
      assert_equal [1, 2], positions
    end

    test 'create rejects duplicate card' do
      @playlist.playlist_cards.create!(card: @card, position: 0)
      assert_no_difference 'PlaylistCard.count' do
        post playlist_cards_path(@playlist), params: { card_id: @card.id }
      end
    end

    test 'destroy removes card from playlist' do
      pc = @playlist.playlist_cards.create!(card: @card, position: 0)
      assert_difference 'PlaylistCard.count', -1 do
        delete playlist_card_path(@playlist, pc)
      end
      assert_redirected_to playlist_path(@playlist)
    end

    private

    def create_card(user)
      draft = Draft.create!
      user.cards.create!(cardable: draft, content: "Test card #{SecureRandom.hex(4)}")
    end
  end
end
