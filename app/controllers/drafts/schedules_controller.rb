class Drafts::SchedulesController < ApplicationController
  before_action :set_card

  def create
    @card.cardable.schedule_as_task!(
      tags: params[:tags].to_s.split(",").map(&:strip).reject(&:blank?),
      date: params[:date]
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to drafts_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.drafts.find(params[:draft_id])
  end
end
