# frozen_string_literal: true

module Collections
  # Older pages for the chat-style collection. The cursor is the id of the
  # oldest row already on screen; the response is bare rows so the client can
  # prepend them.
  class BulletsController < ApplicationController
    def index
      bullets = current_collection.bullets.active

      cursor = bullets.find_by(id: params[:before])
      return head :no_content unless cursor

      @bullets = bullets.page_before(cursor)
      return head :no_content if @bullets.empty?

      render :index, layout: false
    end

    private

    def current_collection
      Current.user.collections.active.find(params[:collection_id])
    end
  end
end
