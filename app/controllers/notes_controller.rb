class NotesController < ApplicationController
  layout -> { request.variant.mobile? ? "mobile" : "main-layout" }

  def index
    @cards = set_page_and_extract_portion_from(
      Current.user.cards.notes.includes(:tags).timeline_chronological,
      per_page: [ 15, 30, 50 ]
    )
    @total = Current.user.cards.notes.count
  end
end
