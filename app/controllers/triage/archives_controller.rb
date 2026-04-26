class Triage::ArchivesController < ApplicationController
  before_action :set_card

  def create
    @card.update!(archived: true)

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
