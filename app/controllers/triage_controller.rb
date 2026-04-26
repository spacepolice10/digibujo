class TriageController < ApplicationController
  def show
    @cards = Current.user.cards.includes(:collection).todays.timeline
                  .where("pops_on IS NULL OR pops_on <= ?", Date.current)
                  .where(archived: false)
  end
end
