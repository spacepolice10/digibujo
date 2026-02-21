class Cards::CompletionsController < ApplicationController
  before_action :set_card

  def create
    @card.cardable.update!(done: true, done_at: Time.current)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cards_path }
    end
  end

  def destroy
    @card.cardable.update!(done: false, done_at: nil)
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
