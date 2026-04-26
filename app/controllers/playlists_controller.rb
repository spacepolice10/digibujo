# frozen_string_literal: true

class PlaylistsController < ApplicationController
  before_action :set_playlist, only: %i[show destroy]

  def index
    @playlists = Current.user.playlists.includes(playlist_cards: { card: :collection }).order(created_at: :desc)
  end

  def show; end

  def create
    @playlist = Current.user.playlists.new

    if @playlist.save
      add_card_to_playlist if params[:card_id].present?
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
    @playlist = Current.user.playlists.includes(playlist_cards: { card: :collection }).find(params[:id])
  end

  def add_card_to_playlist
    card = Current.user.cards.find_by(id: params[:card_id])
    return unless card
    @playlist.playlist_cards.create!(card: card, position: 1)
  end
end
