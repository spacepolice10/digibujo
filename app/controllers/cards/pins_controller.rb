class Cards::PinsController < ApplicationController
  before_action :set_card

  def update
    @card.update!(pinned: !@card.pinned?, status: :active)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cards_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:card_id])
  end
end
