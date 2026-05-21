module TimelineHelper
  def prev_date(date)
    date - 1.day
  end

  def next_date(date)
    date + 1.day
  end

  def prev_date_href(date)
    daylog_path_to(prev_date(date))
  end

  def next_date_href(date)
    daylog_path_to(next_date(date))
  end
end
