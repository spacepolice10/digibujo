class PinnedController < ApplicationController
  def index
    @pinned_cards = Current.user.cards.includes(:tags).pinned.order(updated_at: :desc)
  end
end
