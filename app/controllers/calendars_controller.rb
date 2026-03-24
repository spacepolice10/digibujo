class CalendarsController < ApplicationController
  def show
    @year = (params[:year] || Date.today.year).to_i
    start_date = Date.new(@year, 1, 1)
    end_date   = Date.new(@year, 12, 31)

    cards = Current.user.cards
                   .temporal
                   .where(date: start_date..end_date)
                   .order(:date)

    cards_by_month = cards.group_by { |c| c.date.month }

    @months = (1..12).map do |m|
      first_day     = Date.new(@year, m, 1)
      days_in_month = (first_day >> 1) - first_day
      month_cards   = cards_by_month[m] || []

      {
        number:           m,
        name:             first_day.strftime("%b").downcase,
        first_day:        first_day,
        days_in_month:    days_in_month,
        cards:            month_cards,
        dates_with_cards: month_cards.group_by(&:date)
      }
    end
  end
end
