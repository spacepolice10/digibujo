module TimelineHelper
  def prev_date(date)
    date - 1.day
  end

  def next_date(date)
    date + 1.day
  end

  def prev_date_href(date, path_helper:)
    public_send(path_helper, date: prev_date(date).iso8601)
  end

  def next_date_href(date, path_helper:)
    public_send(path_helper, date: next_date(date).iso8601)
  end
end
