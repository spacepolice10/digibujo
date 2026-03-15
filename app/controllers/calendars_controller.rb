class CalendarsController < ApplicationController
  layout -> { "mobile" if request.variant.mobile? }

  def show
    temporal_cards = Current.user.cards
      .where(cardable_type: Card.cardable_types.select { |t| Card.type_capabilities(t)[:temporal] })
      .order(date: :asc)

    today = Date.today
    @today_cards    = temporal_cards.where(date: today)
    @upcoming_cards = temporal_cards.where(date: today + 1..)
    @due_cards      = temporal_cards.where(date: ..today - 1)
  end
end
