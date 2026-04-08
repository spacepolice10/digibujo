# frozen_string_literal: true

module Cards
  class PlaylistPickersController < ApplicationController
    def show
      @card = Current.user.cards.find(params[:card_id])
      @playlists = Current.user.playlists.order(created_at: :desc)
      @membership = PlaylistCard.where(playlist: @playlists, card: @card).index_by(&:playlist_id)
    end
  end
end
