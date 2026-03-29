# frozen_string_literal: true

class PlaylistsController < ApplicationController
  layout -> { request.variant.mobile? ? 'mobile' : 'main-layout' }

  before_action :set_playlist, only: %i[show destroy]

  def index
    @playlists = Current.user.playlists.includes(playlist_cards: { card: :tags }).order(created_at: :desc)
  end

  def show; end

  def create
    @playlist = Current.user.playlists.new

    if @playlist.save
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
    @playlist = Current.user.playlists.includes(playlist_cards: { card: :tags }).find(params[:id])
  end
end
