class Cards::FieldsController < ApplicationController
  def show
    cardable_type = params[:id].to_s.classify
    unless Card.cardable_types.include?(cardable_type)
      return head :not_found
    end

    @card = Card.new(cardable: cardable_type.constantize.new)
  end
end
