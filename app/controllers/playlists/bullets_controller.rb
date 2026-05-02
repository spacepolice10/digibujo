# frozen_string_literal: true

module Playlists
  class BulletsController < ApplicationController
    before_action :set_playlist

    def create
      bullet = Current.user.bullets.find(params[:bullet_id])
      next_position = @playlist.playlist_bullets.maximum(:position).to_i + 1
      @playlist_bullet = @playlist.playlist_bullets.new(bullet: bullet, position: next_position)

      if @playlist_bullet.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @playlist }
        end
      else
        redirect_to bullets_path, alert: @playlist_bullet.errors.full_messages.to_sentence
      end
    end

    def destroy
      @playlist_bullet = @playlist.playlist_bullets.find(params[:id])
      @playlist_bullet.destroy

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @playlist }
      end
    end

    private

    def set_playlist
      @playlist = Current.user.playlists.find(params[:playlist_id])
    end
  end
end
