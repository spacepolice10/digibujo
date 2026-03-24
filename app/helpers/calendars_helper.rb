module CalendarsHelper
  DAY_LABELS = %w[S M T W T F S].freeze

  def calendar_weeks(first_day, days_in_month)
    leading = first_day.wday
    cells   = Array.new(leading, nil) + (1..days_in_month).to_a
    cells  += Array.new((7 - cells.length % 7) % 7, nil)
    cells.each_slice(7).to_a
  end
end
