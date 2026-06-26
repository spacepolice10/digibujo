# frozen_string_literal: true

class SearchesController < ApplicationController
  def show
    @q = params[:q].to_s.strip

    if @q.present?
      @entries = Search::GlobalRequest.call(user: Current.user, query: @q)
    else
      @selections = Search::Selection.in_menu(Current.user)
    end
  end
end
