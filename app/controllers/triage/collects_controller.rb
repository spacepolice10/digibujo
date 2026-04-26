class Triage::CollectsController < ApplicationController
  before_action :set_card

  def create
    @card.collect!(collection_id: params[:collection_id], collection_name: params[:collection_name])

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to triage_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.todays.find(params[:card_id])
  end

end
