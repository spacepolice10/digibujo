class PinnedController < ApplicationController
  def index
    @pinned_cards = Current.user.cards.includes(:tags).pinned.order(updated_at: :desc)
    @draft_cards = Current.user.cards.drafts.where(pops_on: nil, archived: false).order(created_at: :desc).limit(3)
  end

  def list
    @pinned_cards = Current.user.cards.includes(:tags).pinned.order(updated_at: :desc)
  end
end
