class Cards::FieldsController < ApplicationController
  def show
    type = params[:id].classify
    @fields = Card.cardable_types.include?(type) ? type.constantize.form_fields : []
    @card = Card.new
  end
end
