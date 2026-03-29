# frozen_string_literal: true

module Playlists
  class CardsController < ApplicationController
    before_action :set_playlist

    def create
      card = Current.user.cards.find(params[:card_id])
      next_position = @playlist.playlist_cards.maximum(:position).to_i + 1
      @playlist_card = @playlist.playlist_cards.new(card: card, position: next_position)

      if @playlist_card.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @playlist }
        end
      else
        redirect_to cards_path, alert: @playlist_card.errors.full_messages.to_sentence
      end
    end

    def destroy
      @playlist_card = @playlist.playlist_cards.find(params[:id])
      @playlist_card.destroy

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
