class DaylogsController < ApplicationController
  layout -> { request.variant.mobile? ? "mobile" : "main-layout" }

  def index
    @cards       = set_page_and_extract_portion_from(
      Current.user.cards.daylogs.includes(:tags).timeline_chronological,
      per_page: [ 15, 30, 50 ]
    )
    @total       = Current.user.cards.daylogs.count
    @mood_counts = Daylog.joins(:card).where(cards: { user: Current.user }).group(:mood).count
  end
end
