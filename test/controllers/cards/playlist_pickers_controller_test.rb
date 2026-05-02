# frozen_string_literal: true

require "test_helper"

module Cards
  class PlaylistPickersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      draft = Draft.create!
      @card = @user.bullets.create!(bulletable: draft, content: "Test card")
    end

    test "show returns success" do
      get bullet_playlist_picker_path(@card)
      assert_response :success
    end

    test "show renders all user playlists" do
      playlist = @user.playlists.create!
      get bullet_playlist_picker_path(@card)
      assert_select "form[action*='#{playlist_bullets_path(playlist)}']"
    end

    test "show renders added state for playlists the card is already in" do
      playlist = @user.playlists.create!
      pc = playlist.playlist_cards.create!(card: @card, position: 1)
      get bullet_playlist_picker_path(@card)
      assert_select "form[action='#{playlist_bullet_path(playlist, pc)}']"
      assert_match "tap to remove", response.body
    end

    test "show does not expose another user's card" do
      other_card = users(:two).bullets.create!(bulletable: Draft.create!, content: "Other")
      get bullet_playlist_picker_path(other_card)
      assert_response :not_found
    end
  end
end
