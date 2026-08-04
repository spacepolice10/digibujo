# frozen_string_literal: true

module Collections
  # Older pages for the chat-style collection. The cursor is the id of the
  # oldest row already on screen; the response is bare rows so the client can
  # prepend them. Date pills only come from the full-page show render.
  class BulletsController < ApplicationController
    def index
      bullets = being_at_current_collection_bucket

      cursor = bullets.find_by(id: params[:before])
      return head :no_content unless cursor

      @bullets = bullets.page_before(cursor)
      return head :no_content if @bullets.empty?

      render :index, layout: false
    end

    private

    # @return [Bullet::ActiveRecord_Relation]
    def being_at_current_collection_bucket
      collection = Current.user.collections.merge(Bucket.active).find(params[:collection_id])
      collection.bucket.bullets.active
    end
  end
end
