module TimelineHelper
  def prev_date(date)
    date - 1.day
  end

  def next_date(date)
    date + 1.day
  end

  def prev_date_href(date)
    daylog_path(date: prev_date(date).iso8601)
  end

  def next_date_href(date)
    daylog_path(date: next_date(date).iso8601)
  end
end
