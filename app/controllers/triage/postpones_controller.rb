class Triage::PostponesController < ApplicationController
  before_action :set_card

  def create
    @card.update!(pops_on: postpone_date)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to triage_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.todays.find(params[:card_id])
  end

  def postpone_date
    1.day.from_now.to_date
  end
end
