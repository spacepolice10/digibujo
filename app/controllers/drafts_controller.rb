class DraftsController < ApplicationController
  def index
    @cards = Current.user.cards.includes(:tags).drafts
                    .where(pops_on: nil, archived: false)
                    .order(created_at: :desc)
  end
end
