class Cards::PublishesController < ApplicationController
  before_action :set_card

  def update
    if @card.published?
      @card.unpublish!
    else
      @card.publish!
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @card }
    end
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:card_id])
  end
end
