class EventsController < ApplicationController
  layout -> { request.variant.mobile? ? "mobile" : "main-layout" }

  def index
    @cards    = set_page_and_extract_portion_from(
      Current.user.cards.events.includes(:tags).timeline_chronological,
      per_page: [ 15, 30, 50 ]
    )
    today     = Date.today
    @upcoming = Current.user.cards.events.where("date >= ?", today).count
    @past     = Current.user.cards.events.where("date < ?", today).count
  end
end
