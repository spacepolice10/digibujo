# frozen_string_literal: true

class SearchPalettesController < ApplicationController
  include Search

  BUCKET_LIMIT = 5
  BULLET_LIMIT = 8

  def show
    @q = q
    @buckets = search_buckets.limit(BUCKET_LIMIT)
    @bullets = search_bullets.limit(BULLET_LIMIT)
    @buckets_overflow = search_buckets.offset(BUCKET_LIMIT).exists?
    @bullets_overflow = search_bullets.offset(BULLET_LIMIT).exists?

    respond_to do |format|
      format.turbo_stream
    end
  end
end
