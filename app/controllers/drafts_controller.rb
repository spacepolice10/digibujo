class DraftsController < ApplicationController
  def index
    @cards = Current.user.cards.includes(:tags).draft
               .where(pops_on: nil)
               .order(created_at: :desc)
  end
end
