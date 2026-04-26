class Cards::CompletesController < ApplicationController
  before_action :set_card
  before_action :set_render_partial

  def create
    @card.complete!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cards_path }
    end
  end

  def destroy
    @card.uncomplete!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cards_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:card_id])
  end

  def set_render_partial
    @card_partial = request.referer.to_s.include?("/triage") ? "triage/card" : "cards/card"
  end
end
