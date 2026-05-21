class CalendarsController < ApplicationController
  def show
    @year = (params[:year] || Date.current.year).to_i
    start_date = Date.new(@year, 1, 1)
    end_date   = Date.new(@year, 12, 31)

    bullets = Current.user.bullets
                   .temporal
                   .where(pops_on: start_date..end_date)
                   .order(:pops_on)

    bullets_by_month = bullets.group_by { |c| c.pops_on.month }

    @months = (1..12).map do |m|
      first_day     = Date.new(@year, m, 1)
      days_in_month = (first_day >> 1) - first_day
      month_bullets   = bullets_by_month[m] || []

      {
        number:           m,
        name:             first_day.strftime("%b").downcase,
        first_day:        first_day,
        days_in_month:    days_in_month,
        bullets:            month_bullets,
        dates_with_bullets: month_bullets.group_by(&:pops_on)
      }
    end
  end
end
