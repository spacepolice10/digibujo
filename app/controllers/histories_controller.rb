class HistoriesController < ApplicationController
  def show
    @bullets = set_page_and_extract_portion_from(
      # Date must be todays or past date
      Current.user.bullets.includes(:project).timeline_chronological.where("created_at <= ?", Date.current),
      per_page: [5, 15, 30, 50]
    )
  end
end
