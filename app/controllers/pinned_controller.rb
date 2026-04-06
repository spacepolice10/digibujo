class PinnedController < ApplicationController
  layout -> { request.variant.mobile? ? "mobile" : "main-layout" }

  def index
    @pinned_cards = Current.user.cards.includes(:tags).pinned.order(updated_at: :desc)
    @playlists = Current.user.playlists.includes(playlist_cards: { card: :tags }).order(created_at: :desc)
  end
end
