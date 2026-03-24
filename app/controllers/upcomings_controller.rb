class UpcomingsController < ApplicationController
  layout -> { 'mobile' if request.variant.mobile? }

  def show
    temporal_cards =
      Current.user.cards
             .temporal
             .where(done: [false, nil])
    today = Date.today
    @today_cards    = temporal_cards.where(date: today)
    @upcoming_cards = temporal_cards.where(date: today + 1..)
    @due_cards      = temporal_cards.where(date: ..today - 1).where.not(cardable_type: 'Event')
  end
end
