# frozen_string_literal: true

class SearchesController < ApplicationController
  def show
    @q = params[:q].to_s.strip
    results = Search::GlobalRequest.call(user: Current.user, query: @q)

    @projects = results.projects
    @buckets = results.buckets
    @bullets = results.bullets
    @people = results.people
  end
end
