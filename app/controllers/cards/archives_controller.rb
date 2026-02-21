class Cards::ArchivesController < ApplicationController
  before_action :set_card

  def update
    new_status = @card.archived? ? :active : :archived
    if @card.update(status: new_status, pinned: false)
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
