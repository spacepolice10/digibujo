# frozen_string_literal: true

module Daylogs
  # Older pages for the chat-style daylog. The cursor is the id of the oldest row
  # already on screen; the response is bare rows so the client can prepend them.
  class BulletsController < ApplicationController
    def index
      cursor = daylog_bullets.find_by(id: params[:before])
      return head :no_content unless cursor

      @bullets = daylog_bullets.where(pops_on: cursor.pops_on).page_before(cursor)
      return head :no_content if @bullets.empty?

      render layout: false
    end

    private

    def daylog_bullets
      daylog = Current.user.daylog
      daylog ? daylog.bullets.active : Bullet.none
    end
  end
end
