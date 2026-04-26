class ArchivedController < ApplicationController
  def index
    @cards = set_page_and_extract_portion_from(
      Current.user.cards.includes(:collection).archived.order(updated_at: :desc),
      per_page: [ 15, 30, 50 ]
    )
    @total = Current.user.cards.archived.count
  end
end
