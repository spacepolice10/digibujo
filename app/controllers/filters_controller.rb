class FiltersController < ApplicationController
  def index
    @filters = Current.user.filters.named
  end

  def show
    @filter = Current.user.filters.find(params[:id])
    @cards = @filter.cards
  end
end
