# frozen_string_literal: true

module Futures
  # Older pages for the chat-style future log. The cursor is the id of the
  # oldest row already on screen; the response is bare rows so the client can
  # prepend them. Only unplanned bullets (`pops_on` nil) live on the rail.
  class BulletsController < ApplicationController
    def index
      @future = Current.user.futures.find(params[:future_id])
      scoped = @future.bullets.active.where(pops_on: nil).includes(:bulletable)

      if params[:before].present?
        cursor = scoped.find_by(id: params[:before])
        return head :no_content unless cursor

        @bullets = scoped.page_before(cursor)
        return head :no_content if @bullets.empty?

        render layout: false
      else
        @bullets = scoped.last_page
        @more_bullets = @bullets.size == Bullet::Pageable::PAGE_SIZE
      end
    end
  end
end
