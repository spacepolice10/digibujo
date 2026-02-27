class Cards::PopsController < ApplicationController
  before_action :set_card

  def update
    new_pops_on = if params[:pops_on].present?
      Date.parse(params[:pops_on])
    elsif @card.pops_on.present?
      nil       # dismiss
    else
      Date.today  # pop now
    end

    if @card.update(pops_on: new_pops_on)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to cards_path }
      end
    else
      redirect_to cards_path, alert: @card.errors.full_messages.to_sentence
    end
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:card_id])
  end
end
