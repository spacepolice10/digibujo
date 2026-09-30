# frozen_string_literal: true

module Timelines
  # Older pages for the chat-style timeline. The cursor is the id of the oldest
  # row already on screen; the response is bare rows so the client can prepend them.
  class BulletsController < ApplicationController
    def index
      @timeline = Current.user.timeline
      cursor = @timeline.bullets.find_by(id: params[:before])
      return head :no_content unless cursor

      @bullets = @timeline.page_before(cursor)
      return head :no_content if @bullets.empty?

      @cursor = cursor
      respond_to do |format|
        format.html { render layout: false }
        format.json { render if stale?(etag: @bullets) }
      end
    end
  end
end
