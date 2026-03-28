class ArchivedController < ApplicationController
  layout -> { request.variant.mobile? ? "mobile" : "main-layout" }

  def index
    @cards = set_page_and_extract_portion_from(
      Current.user.cards.includes(:tags).archived.order(updated_at: :desc),
      per_page: [ 15, 30, 50 ]
    )
    @total = Current.user.cards.archived.count
  end
end
