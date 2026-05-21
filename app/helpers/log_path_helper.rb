# frozen_string_literal: true

module LogPathHelper
  def daylog_path_to(date, **options)
    path_options = options.compact
    if date == Date.current
      daylog_path(path_options)
    else
      daylog_on_path(year: date.year, month: date.month, day: date.day, **path_options)
    end
  end

  def monthlylog_path_to(date, **options)
    anchor = date.beginning_of_month
    path_options = options.compact
    if anchor.year == Date.current.year && anchor.month == Date.current.month
      monthlylog_path(path_options)
    else
      monthlylog_on_path(year: anchor.year, month: anchor.month, **path_options)
    end
  end
end
