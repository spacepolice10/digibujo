# frozen_string_literal: true

module Playlists
  class ReordersController < ApplicationController
    before_action :set_playlist

    def update
      positions = params.require(:positions)

      ActiveRecord::Base.transaction do
        positions.each_with_index do |playlist_bullet_id, index|
          @playlist.playlist_bullets.find(playlist_bullet_id).update!(position: index)
        end
      end

      respond_to do |format|
        format.turbo_stream { head :ok }
        format.html { redirect_to @playlist }
      end
    end

    private

    def set_playlist
      @playlist = Current.user.playlists.find(params[:playlist_id])
    end
  end
end
