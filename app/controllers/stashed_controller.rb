class StashedController < ApplicationController
  def index
    @stashed_cards = Current.user.cards.includes(:tags).stashed.order(updated_at: :desc)
  end
end
