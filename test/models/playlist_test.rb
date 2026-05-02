# frozen_string_literal: true

require 'test_helper'

class PlaylistTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'auto-assigns colour and icon on create' do
    playlist = @user.playlists.create!
    assert_includes Colourable::COLOUR_KEYS, playlist.colour
    assert_includes Iconable::ICON_KEYS, playlist.icon
  end

  test 'colour cycles through 1-8 based on playlist count' do
    @user.playlists.destroy_all
    colours = Colourable::COLOUR_KEYS.size.times.map do
      @user.playlists.create!.colour
    end
    assert_equal Colourable::COLOUR_KEYS, colours
  end

  test 'icon cycles through ICON_KEYS based on playlist count' do
    @user.playlists.destroy_all
    icons = Iconable::ICON_KEYS.size.times.map do
      @user.playlists.create!.icon
    end
    assert_equal Iconable::ICON_KEYS, icons
  end

  test 'playlist_cards are ordered by position' do
    playlist = @user.playlists.create!
    card_a = create_card(@user)
    card_b = create_card(@user)
    playlist.playlist_cards.create!(card: card_b, position: 1)
    playlist.playlist_cards.create!(card: card_a, position: 0)

    assert_equal [card_a, card_b], playlist.bullets.to_a
  end

  test 'destroying playlist destroys playlist_cards' do
    playlist = @user.playlists.create!
    card = create_card(@user)
    playlist.playlist_cards.create!(card: card, position: 0)

    assert_difference 'PlaylistCard.count', -1 do
      playlist.destroy
    end
  end

  test 'destroying card destroys its playlist_cards' do
    playlist = @user.playlists.create!
    card = create_card(@user)
    playlist.playlist_cards.create!(card: card, position: 0)

    assert_difference 'PlaylistCard.count', -1 do
      card.destroy
    end
  end

  test 'card cannot be added to same playlist twice' do
    playlist = @user.playlists.create!
    card = create_card(@user)
    playlist.playlist_cards.create!(card: card, position: 0)

    duplicate = playlist.playlist_cards.build(card: card, position: 1)
    assert_not duplicate.valid?
  end

  test 'card can be in multiple playlists' do
    playlist_a = @user.playlists.create!
    playlist_b = @user.playlists.create!
    card = create_card(@user)

    playlist_a.playlist_cards.create!(card: card, position: 0)
    playlist_b.playlist_cards.create!(card: card, position: 0)

    assert_includes playlist_a.bullets, card
    assert_includes playlist_b.bullets, card
  end

  private

  def create_card(user)
    draft = Draft.create!
    user.bullets.create!(bulletable: draft, content: "Test card #{SecureRandom.hex(4)}")
  end
end
