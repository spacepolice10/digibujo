# frozen_string_literal: true

class SearchesController < ApplicationController
  include Search

  BUCKET_LIMIT = 5
  BULLET_LIMIT = 8

  def show
    @q = q
    @projects = search_projects.limit(BUCKET_LIMIT)
    @buckets = search_buckets.limit(BUCKET_LIMIT)
    @bullets = search_bullets.limit(BULLET_LIMIT)
  end
end
