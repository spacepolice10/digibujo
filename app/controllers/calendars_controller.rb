class CalendarsController < ApplicationController
  def show
    @cards_by_date = Current.user.cards
      .where(cardable_type: Card.cardable_types.select { |t| Card.type_capabilities(t)[:temporal] })
      .order(date: :desc)
      .group_by(&:date)
  end
end
