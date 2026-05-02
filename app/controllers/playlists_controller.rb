# frozen_string_literal: true

class PlaylistsController < ApplicationController
  before_action :set_playlist, only: %i[show destroy]

  def index
    @playlists = Current.user.playlists.includes(playlist_bullets: { bullet: :project }).order(created_at: :desc)
  end

  def show; end

  def create
    @playlist = Current.user.playlists.new

    if @playlist.save
      add_bullet_to_playlist if params[:bullet_id].present?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to playlists_path }
      end
    else
      redirect_to playlists_path, alert: @playlist.errors.full_messages.to_sentence
    end
  end

  def destroy
    @playlist.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to playlists_path }
    end
  end

  private

  def set_playlist
    @playlist = Current.user.playlists.includes(playlist_bullets: { bullet: :project }).find(params[:id])
  end

  def add_bullet_to_playlist
    bullet = Current.user.bullets.find_by(id: params[:bullet_id])
    return unless bullet
    @playlist.playlist_bullets.create!(bullet: bullet, position: 1)
  end
end
