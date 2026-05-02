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
        post playlist_bullets_path(@playlist), params: { bullet_id: @card.id }
      end
      assert_redirected_to playlist_path(@playlist)
    end

    test 'create assigns incrementing position' do
      post playlist_bullets_path(@playlist), params: { bullet_id: @card.id }
      card_b = create_card(@user)
      post playlist_bullets_path(@playlist), params: { bullet_id: card_b.id }

      positions = @playlist.playlist_cards.reload.pluck(:position)
      assert_equal [1, 2], positions
    end

    test 'create rejects duplicate card' do
      @playlist.playlist_cards.create!(card: @card, position: 0)
      assert_no_difference 'PlaylistCard.count' do
        post playlist_bullets_path(@playlist), params: { bullet_id: @card.id }
      end
    end

    test 'destroy removes card from playlist' do
      pc = @playlist.playlist_cards.create!(card: @card, position: 0)
      assert_difference 'PlaylistCard.count', -1 do
        delete playlist_bullet_path(@playlist, pc)
      end
      assert_redirected_to playlist_path(@playlist)
    end

    test 'create responds with turbo stream when called with JSON body' do
      post playlist_bullets_path(@playlist),
           params: { bullet_id: @card.id }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Accept' => 'text/vnd.turbo-stream.html' }
      assert_response :success
      assert_equal 'text/vnd.turbo-stream.html', response.media_type
    end

    private

    def create_card(user)
      draft = Draft.create!
      user.bullets.create!(bulletable: draft, content: "Test card #{SecureRandom.hex(4)}")
    end
  end
end
