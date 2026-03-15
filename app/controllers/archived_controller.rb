class ArchivedController < ApplicationController
  def index
    @archived_cards = Current.user.cards.includes(:tags).archived.order(updated_at: :desc)
  end
end
