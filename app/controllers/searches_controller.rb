# frozen_string_literal: true

class SearchesController < ApplicationController
  include Search

  def show
    @q = q
    @projects = search_projects
    @buckets = search_buckets
    @bullets = set_page_and_extract_portion_from(search_bullets, per_page: [5, 15, 30, 50])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
