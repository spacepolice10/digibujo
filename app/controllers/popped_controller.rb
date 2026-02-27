class PoppedController < ApplicationController
  def index
    @popped_cards = Current.user.cards.includes(:cardable, :tags).popped.order(pops_on: :asc)
  end
end
