class PinnedController < ApplicationController
  def index
    @pinned_cards = Current.user.cards.includes(:collection).pinned.order(updated_at: :desc)
    @playlists = Current.user.playlists.includes(playlist_cards: { card: :collection }).order(created_at: :desc)
  end
end
