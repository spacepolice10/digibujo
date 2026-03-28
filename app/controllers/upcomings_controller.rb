class UpcomingsController < ApplicationController
  layout -> { 'mobile' if request.variant.mobile? }

  def show
    temporal_cards =
      Current.user.cards
             .temporal
    today = Date.today
    @today_cards    = temporal_cards.where(date: today.all_day)
    @upcoming_cards = temporal_cards.where(date: today.tomorrow.beginning_of_day..)
    @due_cards      = temporal_cards.where(done: [false,
                                                  nil])
                                    .where(date: ..today.beginning_of_day)
                                    .where.not(cardable_type: 'Event')
  end
end
