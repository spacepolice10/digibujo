class Cards::CardableTypesController < ApplicationController
  before_action :set_card, only: :update

  def show
    type = params[:id].classify
    raise ActionController::BadRequest unless Card.cardable_types.include?(type)
    @fields = type.constantize.new.form_fields
    @card   = Card.new
  end

  def update
    target_type = params[:cardable_type].to_s.classify
    unless Card.cardable_types.include?(target_type)
      return redirect_to popped_index_path, alert: "Invalid type"
    end
    return redirect_to popped_index_path if @card.cardable_type == target_type

    new_cardable = target_type.constantize.create!
    old_cardable = @card.cardable
    @card.update!(cardable_type: target_type, cardable_id: new_cardable.id)
    old_cardable.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to popped_index_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:card_id])
  end
end
