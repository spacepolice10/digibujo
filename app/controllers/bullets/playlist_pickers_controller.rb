# frozen_string_literal: true

module Bullets
  class PlaylistPickersController < ApplicationController
    def show
      @bullet = Current.user.bullets.find(params[:bullet_id])
      @playlists = Current.user.playlists.order(created_at: :desc)
      @membership = PlaylistCard.where(playlist: @playlists, bullet: @bullet).index_by(&:playlist_id)
    end
  end
end
