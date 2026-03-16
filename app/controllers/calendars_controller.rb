class CalendarsController < ApplicationController
  layout -> { 'mobile' if request.variant.mobile? }

  def show
    temporal_cards =
      Current.user.cards
             .temporal
    today = Date.today
    @today_cards    = temporal_cards.where(date: today)
    @upcoming_cards = temporal_cards.where(date: today + 1..)
    @due_cards      = temporal_cards.where(date: ..today - 1)
  end
end
