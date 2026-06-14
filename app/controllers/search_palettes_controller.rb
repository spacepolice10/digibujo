# frozen_string_literal: true

class SearchPalettesController < ApplicationController
  include Search

  BUCKET_LIMIT = 5
  BULLET_LIMIT = 8

  def show
    @q = q
    @projects = search_projects.limit(BUCKET_LIMIT)
    @buckets = search_buckets.limit(BUCKET_LIMIT)
    @bullets = search_bullets.limit(BULLET_LIMIT)
    @projects_overflow = search_projects.offset(BUCKET_LIMIT).exists?
    @buckets_overflow = search_buckets.offset(BUCKET_LIMIT).exists?
    @bullets_overflow = search_bullets.offset(BULLET_LIMIT).exists?

    respond_to do |format|
      format.turbo_stream
    end
  end
end
