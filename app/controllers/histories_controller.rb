class HistoriesController < ApplicationController
  def show
    @cards = set_page_and_extract_portion_from(
      # Date must be todays or past date
      Current.user.cards.includes(:collection).timeline_chronological.where("created_at <= ?", Date.current),
      per_page: [5, 15, 30, 50]
    )
  end
end
