# frozen_string_literal: true

require 'test_helper'

class PlaylistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index returns success' do
    get playlists_path
    assert_response :success
  end

  test 'show returns success' do
    playlist = @user.playlists.create!
    get playlist_path(playlist)
    assert_response :success
  end

  test 'create makes a new playlist with auto identity' do
    assert_difference 'Playlist.count', 1 do
      post playlists_path
    end
    assert_redirected_to playlists_path

    playlist = @user.playlists.order(created_at: :desc).first
    assert_includes Colourable::COLOUR_KEYS, playlist.colour
    assert_includes Iconable::ICON_KEYS, playlist.icon
  end

  test 'destroy deletes playlist' do
    playlist = @user.playlists.create!
    assert_difference 'Playlist.count', -1 do
      delete playlist_path(playlist)
    end
    assert_redirected_to playlists_path
  end

  test 'create with bullet_id adds card to new playlist' do
    draft = Draft.create!
    card = @user.bullets.create!(bulletable: draft, content: "Test")
    assert_difference [ 'Playlist.count', 'PlaylistCard.count' ], 1 do
      post playlists_path, params: { bullet_id: card.id }
    end
    playlist = @user.playlists.order(created_at: :desc).first
    assert playlist.bullets.include?(card)
  end

  test "cannot access another user's playlist" do
    other = users(:two)
    playlist = other.playlists.create!
    get playlist_path(playlist)
    assert_response :not_found
  end
end
