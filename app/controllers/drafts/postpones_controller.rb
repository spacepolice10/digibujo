class Drafts::PostponesController < ApplicationController
  before_action :set_card

  def create
    @card.update!(pops_on: params[:pops_on])

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to drafts_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.draft.find(params[:draft_id])
  end
end
